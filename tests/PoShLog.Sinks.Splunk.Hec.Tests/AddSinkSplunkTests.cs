using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text.Json;

namespace PoShLog.Sinks.Splunk.Hec.Tests;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class LoggerCollection
{
	// Start-Logger sets the process-wide [Serilog.Log]::Logger, so these tests run one at a time.
	public const string Name = "Serilog global logger";
}

/// <summary>
/// Runs Add-SinkSplunk in a PowerShell runspace with Core and the compiled cmdlet imported, against a local HTTP Event
/// Collector stand-in.
/// </summary>
[Collection(LoggerCollection.Name)]
public sealed class AddSinkSplunkTests : IAsyncLifetime
{
	private const string Token = "00000000-0000-0000-0000-000000000000";
	private static readonly TimeSpan Delivery = TimeSpan.FromSeconds(20);
	private HecReceiver _receiver = null!;
	private PowerShell _shell = null!;

	public async Task InitializeAsync()
	{
		_receiver = await HecReceiver.StartAsync(Token);
		var state = InitialSessionState.CreateDefault();
		if (OperatingSystem.IsWindows())
		{
			state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
		}
		var runspace = RunspaceFactory.CreateRunspace(state);
		runspace.Open();
		_shell = PowerShell.Create(runspace);
		Invoke($"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Core.dll")}' -ErrorAction Stop; " +
			$"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Sinks.Splunk.Hec.dll")}' -ErrorAction Stop");
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
		var result = Assert.Single(Invoke($"New-Logger | Add-SinkSplunk -Url '{_receiver.Url}' -Token '{Token}'"));

		Assert.Equal("Serilog.LoggerConfiguration", result.BaseObject.GetType().FullName);
	}

	[Fact]
	public void InvalidUrl_FailsWithAClearError()
	{
		var error = Assert.ThrowsAny<Exception>(() => Invoke($"New-Logger | Add-SinkSplunk -Url 'splunk:8088' -Token '{Token}' -ErrorAction Stop"));

		Assert.Contains("not an absolute http or https URL", error.Message);
	}

	[Fact]
	public void EventEndpoint_DeliversTheEventWithTokenEnvelopeAndFields()
	{
		var marker = "hec-event-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkSplunk '{{_receiver.Url}}' '{{Token}}' -Index 'main' -Source 'pester' -SourceType '_json' -Host 'box1' `
				-Fields @{ team = 'ops' } -BatchInterval 0.1 | Start-Logger
			Write-InfoLog '{{marker}} {Count}' -PropertyValues 3
			Close-Logger
			""");

		var request = _receiver.WaitFor(marker, Delivery);
		Assert.Equal("/services/collector/event", request.Path);
		Assert.StartsWith("application/json", request.ContentType);
		Assert.Equal($"Splunk {Token}", request.Headers["authorization"]);
		Assert.True(Guid.TryParse(request.Headers["x-splunk-request-channel"], out _));
		using var json = JsonDocument.Parse(request.Body);
		var root = json.RootElement;
		Assert.Equal("main", root.GetProperty("index").GetString());
		Assert.Equal("pester", root.GetProperty("source").GetString());
		Assert.Equal("_json", root.GetProperty("sourcetype").GetString());
		Assert.Equal("box1", root.GetProperty("host").GetString());
		Assert.Equal("ops", root.GetProperty("fields").GetProperty("team").GetString());
		Assert.Equal(3, root.GetProperty("event").GetProperty("Properties").GetProperty("Count").GetInt32());
	}

	[Fact]
	public void RawEndpoint_DeliversTextLinesWithMetadataInTheQuery()
	{
		var marker = "hec-raw-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkSplunk -Url '{{_receiver.Url}}' -Token '{{Token}}' -Endpoint Raw -Index 'main' -SourceType 'poshlog:raw' `
				-OutputTemplate '[{Level:u3}] {Message:lj}{NewLine}' -BatchInterval 0.1 | Start-Logger
			Write-WarningLog '{{marker}}'
			Close-Logger
			""");

		var request = _receiver.WaitFor(marker, Delivery);
		Assert.Equal("/services/collector/raw", request.Path);
		Assert.Equal("?index=main&sourcetype=poshlog%3Araw", request.Query);
		Assert.Equal($"[WRN] {marker}", request.Body.TrimEnd());
	}

	[Fact]
	public void MigrationNames_FromTheThirdPartyModuleStillBind()
	{
		var marker = "hec-migration-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkSplunk -SplunkHost '{{_receiver.Url}}' -EventCollectorToken '{{Token}}' -HostName 'box2' -BatchIntervalSeconds 1 | Start-Logger
			Write-InfoLog '{{marker}}'
			Close-Logger
			""");

		using var json = JsonDocument.Parse(_receiver.WaitFor(marker, Delivery).Body);
		Assert.Equal("box2", json.RootElement.GetProperty("host").GetString());
	}

	[Fact]
	public void Exception_IsPartOfTheEvent()
	{
		var marker = "hec-exception-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkSplunk -Url '{{_receiver.Url}}' -Token '{{Token}}' -BatchInterval 0.1 | Start-Logger
			Write-ErrorLog '{{marker}}' -Exception ([System.IO.FileNotFoundException]::new('missing.txt'))
			Close-Logger
			""");

		using var json = JsonDocument.Parse(_receiver.WaitFor(marker, Delivery).Body);
		Assert.Contains("System.IO.FileNotFoundException", json.RootElement.GetProperty("event").GetProperty("Exception").GetString());
	}

	[Fact]
	public void BatchSizeLimit_SplitsRequests()
	{
		var marker = "hec-batch-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkSplunk -Url '{{_receiver.Url}}' -Token '{{Token}}' -BatchSizeLimit 1 -BatchInterval 0.1 | Start-Logger
			Write-InfoLog '{{marker}}-1'
			Write-InfoLog '{{marker}}-2'
			Close-Logger
			""");

		Assert.DoesNotContain($"{marker}-2", _receiver.WaitFor($"{marker}-1", Delivery).Body);
		Assert.DoesNotContain($"{marker}-1", _receiver.WaitFor($"{marker}-2", Delivery).Body);
	}

	[Fact]
	public void RestrictedToMinimumLevel_DropsLowerEvents()
	{
		var dropped = "hec-dropped-" + Guid.NewGuid().ToString("N");
		var kept = "hec-kept-" + Guid.NewGuid().ToString("N");

		Invoke($$"""
			New-Logger | Add-SinkSplunk -Url '{{_receiver.Url}}' -Token '{{Token}}' -RestrictedToMinimumLevel Warning -BatchInterval 0.1 | Start-Logger
			Write-InfoLog '{{dropped}}'
			Write-ErrorLog '{{kept}}'
			Close-Logger
			""");

		Assert.DoesNotContain(dropped, _receiver.WaitFor(kept, Delivery).Body);
		Assert.DoesNotContain(_receiver.Requests.ToArray(), r => r.Body.Contains(dropped));
	}

	[Fact]
	public void RejectedToken_IsDiscardedWithoutBreakingLogging()
	{
		var marker = "hec-forbidden-" + Guid.NewGuid().ToString("N");

		// Splunk answers 403 for a bad token; the package drops the batch (SelfLog) instead of retrying it.
		Invoke($$"""
			New-Logger | Add-SinkSplunk -Url '{{_receiver.Url}}' -Token 'wrong-placeholder' -BatchInterval 0.1 | Start-Logger
			Write-InfoLog '{{marker}}'
			Close-Logger
			""");

		var request = _receiver.WaitFor(marker, Delivery);
		Assert.Equal("Splunk wrong-placeholder", request.Headers["authorization"]);
		Assert.DoesNotContain(_receiver.Requests.ToArray(), r => r.Body.Contains(marker));
	}
}
