using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace PoShLog.Sinks.OpenTelemetry.Tests;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class LoggerCollection
{
	// Start-Logger sets the process-wide [Serilog.Log]::Logger, so these tests run one at a time.
	public const string Name = "Serilog global logger";
}

/// <summary>
/// Runs Add-SinkOpenTelemetry in a PowerShell runspace with Core and the compiled cmdlet imported, against a local
/// OTLP receiver over HTTP/protobuf and gRPC.
/// </summary>
[Collection(LoggerCollection.Name)]
public sealed class AddSinkOpenTelemetryTests : IAsyncLifetime
{
	private static readonly TimeSpan Delivery = TimeSpan.FromSeconds(20);
	private OtlpReceiver _receiver = null!;
	private PowerShell _shell = null!;

	public async Task InitializeAsync()
	{
		_receiver = await OtlpReceiver.StartAsync();
		var state = InitialSessionState.CreateDefault();
		if (OperatingSystem.IsWindows())
		{
			state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
		}
		var runspace = RunspaceFactory.CreateRunspace(state);
		runspace.Open();
		_shell = PowerShell.Create(runspace);
		Invoke($"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Core.dll")}' -ErrorAction Stop; " +
			$"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Sinks.OpenTelemetry.dll")}' -ErrorAction Stop");
	}

	public async Task DisposeAsync()
	{
		try
		{
			Invoke("Close-Logger", allowErrors: true);
		}
		finally
		{
			var runspace = _shell.Runspace;
			_shell.Dispose();
			runspace.Dispose();
			await _receiver.DisposeAsync();
		}
	}

	private Collection<PSObject> Invoke(string script, bool allowErrors = false)
	{
		_shell.Commands.Clear();
		_shell.Streams.ClearStreams();
		_shell.AddScript(script);
		var results = _shell.Invoke();
		if (_shell.HadErrors && !allowErrors)
		{
			throw new InvalidOperationException(string.Join(Environment.NewLine, _shell.Streams.Error.Select(e => e.ToString())));
		}
		return results;
	}

	[Fact]
	public void ReturnsTheLoggerConfiguration()
	{
		var result = Assert.Single(Invoke("New-Logger | Add-SinkOpenTelemetry -IgnoreEnvironment"));

		Assert.Equal("Serilog.LoggerConfiguration", result.BaseObject.GetType().FullName);
	}

	[Fact]
	public void MissingLoggerConfig_Fails()
	{
		Assert.ThrowsAny<Exception>(() => Invoke("Add-SinkOpenTelemetry -LoggerConfig $null"));
	}

	[Fact]
	public void HttpProtobuf_DeliversTheEventWithResourceAndHeaders()
	{
		var marker = "otlp-http-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkOpenTelemetry -Endpoint '{{_receiver.HttpUrl}}' -Protocol HttpProtobuf -IgnoreEnvironment `
				-ServiceName 'otlp-tests' -Headers @{ 'x-api-key' = 'placeholder' } -ResourceAttributes @{ 'deployment.environment' = 'test' } `
				-Period ([timespan]::FromMilliseconds(100)) | Start-Logger
			Write-InfoLog '{{marker}} {Count}' -PropertyValues 3
			Close-Logger
			""");

		var request = _receiver.WaitFor(marker, Delivery);
		Assert.Equal("/v1/logs", request.Path);
		Assert.Equal("application/x-protobuf", request.ContentType);
		Assert.Equal("placeholder", request.Headers["x-api-key"]);
		Assert.Contains("otlp-tests", request.Strings);
		Assert.Contains("deployment.environment", request.Strings);
		Assert.Contains("Count", request.Strings);
	}

	[Fact]
	public void Grpc_DeliversTheEvent()
	{
		var marker = "otlp-grpc-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkOpenTelemetry -Endpoint '{{_receiver.GrpcUrl}}' -Protocol Grpc -IgnoreEnvironment `
				-ServiceName 'otlp-tests' -Headers @{ 'x-api-key' = 'placeholder' } -Period ([timespan]::FromMilliseconds(100)) | Start-Logger
			Write-WarningLog '{{marker}}'
			Close-Logger
			""");

		var request = _receiver.WaitFor(marker, Delivery);
		Assert.Equal(OtlpReceiver.GrpcExportPath, request.Path);
		Assert.StartsWith("application/grpc", request.ContentType);
		Assert.Equal("placeholder", request.Headers["x-api-key"]);
		Assert.Contains("otlp-tests", request.Strings);
	}

	[Fact]
	public void Exception_IsSentAsOpenTelemetryExceptionAttributes()
	{
		var marker = "otlp-exception-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkOpenTelemetry -Endpoint '{{_receiver.HttpUrl}}' -IgnoreEnvironment -IncludedData 'TemplateBody, SourceContextAttribute' `
				-Period ([timespan]::FromMilliseconds(100)) | Start-Logger
			Write-ErrorLog '{{marker}}' -Exception ([System.IO.FileNotFoundException]::new('missing.txt'))
			Close-Logger
			""");

		var request = _receiver.WaitFor(marker, Delivery);
		Assert.Contains("exception.type", request.Strings);
		Assert.Contains("System.IO.FileNotFoundException", request.Strings);
		Assert.Contains("exception.message", request.Strings);
	}

	[Fact]
	public void RestrictedToMinimumLevel_DropsLowerEvents()
	{
		var dropped = "otlp-dropped-" + Guid.NewGuid().ToString("N");
		var kept = "otlp-kept-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkOpenTelemetry -Endpoint '{{_receiver.HttpUrl}}' -IgnoreEnvironment -RestrictedToMinimumLevel Warning `
				-Period ([timespan]::FromMilliseconds(100)) | Start-Logger
			Write-InfoLog '{{dropped}}'
			Write-ErrorLog '{{kept}}'
			Close-Logger
			""");

		var request = _receiver.WaitFor(kept, Delivery);
		Assert.DoesNotContain(request.Strings, s => s.Contains(dropped));
		Assert.DoesNotContain(_receiver.Requests.ToArray().SelectMany(r => r.Strings), s => s.Contains(dropped));
	}
}
