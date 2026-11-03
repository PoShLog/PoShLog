using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace PoShLog.Sinks.Syslog.Rfc5424.Tests;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class LoggerCollection
{
	// Start-Logger sets the process-wide [Serilog.Log]::Logger, so these tests run one at a time.
	public const string Name = "Serilog global logger";
}

/// <summary>
/// Runs Add-SinkSyslog in a PowerShell runspace with Core and the compiled cmdlet imported, against loopback UDP, TCP and
/// TLS syslog receivers.
/// </summary>
[Collection(LoggerCollection.Name)]
public sealed class AddSinkSyslogTests : IDisposable
{
	private static readonly TimeSpan Delivery = TimeSpan.FromSeconds(20);
	private readonly PowerShell _shell;

	public AddSinkSyslogTests()
	{
		var state = InitialSessionState.CreateDefault();
		if (OperatingSystem.IsWindows())
		{
			state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
		}
		var runspace = RunspaceFactory.CreateRunspace(state);
		runspace.Open();
		_shell = PowerShell.Create(runspace);
		Invoke($"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Core.dll")}' -ErrorAction Stop; " +
			$"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Sinks.Syslog.Rfc5424.dll")}' -ErrorAction Stop");
	}

	public void Dispose()
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

	private string ErrorOf(string script)
	{
		var exception = Assert.ThrowsAny<Exception>(() => Invoke(script));
		return exception.Message;
	}

	[Fact]
	public void ReturnsTheLoggerConfiguration()
	{
		var result = Assert.Single(Invoke("New-Logger | Add-SinkSyslog 'syslog.example.com'"));

		Assert.Equal("Serilog.LoggerConfiguration", result.BaseObject.GetType().FullName);
	}

	[Theory]
	[InlineData("-Framing Lf", "-Framing applies to -Protocol Tcp")]
	[InlineData("-Protocol Tcp -TrustedCertificateThumbprint ('a' * 40)", "apply to -Protocol TcpTls only")]
	[InlineData("-Format Rfc3164 -StructuredDataId 'x@1'", "apply to -Format Rfc5424 only")]
	[InlineData("-StructuredDataId 'a b'", "not a valid RFC 5424 SD-ID")]
	[InlineData("-Protocol TcpTls -TrustedCertificateThumbprint 'abc'", "SHA-1 (40) or SHA-256 (64)")]
	[InlineData("-BatchInterval 0", "BatchInterval must be positive")]
	public void InvalidOptions_FailWithAClearError(string arguments, string expected)
	{
		Assert.Contains(expected, ErrorOf($"New-Logger | Add-SinkSyslog 'syslog.example.com' {arguments}"));
	}

	[Fact]
	public void ThumbprintAndCallbackTogether_FailWithAClearError()
	{
		Assert.Contains("either -TrustedCertificateThumbprint or -CertificateValidationCallback", ErrorOf(
			"New-Logger | Add-SinkSyslog 'syslog.example.com' -Protocol TcpTls -TrustedCertificateThumbprint ('a' * 40) " +
			"-CertificateValidationCallback ([System.Net.Security.RemoteCertificateValidationCallback]{ $true })"));
	}

	[Fact]
	public async Task Udp_DeliversAnRfc5424Datagram()
	{
		await using var receiver = SyslogReceiver.Udp();

		Invoke($"New-Logger | Add-SinkSyslog '127.0.0.1' -Port {receiver.Port} -AppName 'backup' -SourceHost 'web01' -BatchInterval 0.1 | Start-Logger; " +
			"Write-WarningLog 'Backed up {Count} databases udp-marker' -PropertyValues 12");

		Assert.True(await receiver.WaitForAsync("udp-marker", Delivery));
		var datagram = Assert.Single(receiver.Datagrams);
		Assert.StartsWith("<132>1 ", datagram);
		Assert.Contains(" web01 backup ", datagram);
		Assert.EndsWith("[poshlog@32473 Count=\"12\"] Backed up 12 databases udp-marker", datagram);
	}

	[Fact]
	public async Task Tcp_DeliversOctetCountedFrames()
	{
		await using var receiver = SyslogReceiver.Tcp();

		Invoke($"New-Logger | Add-SinkSyslog '127.0.0.1' -Port {receiver.Port} -Protocol Tcp -Format Rfc3164 -BatchInterval 0.1 | Start-Logger; " +
			"Write-InfoLog 'first tcp'; Write-InfoLog 'second tcp-marker'");

		Assert.True(await receiver.WaitForAsync("tcp-marker", Delivery));
		var frames = receiver.OctetCountedFrames();
		Assert.Equal(2, frames.Count);
		Assert.EndsWith(": first tcp", frames[0]);
		Assert.EndsWith(": second tcp-marker", frames[1]);
	}

	[Fact]
	public async Task Tcp_DelimitsWithLineFeeds()
	{
		await using var receiver = SyslogReceiver.Tcp();

		Invoke($"New-Logger | Add-SinkSyslog '127.0.0.1' -Port {receiver.Port} -Protocol Tcp -Framing Lf -BatchInterval 0.1 | Start-Logger; " +
			"Write-InfoLog 'one'; Write-InfoLog 'two lf-marker'");

		Assert.True(await receiver.WaitForAsync("lf-marker", Delivery));
		var lines = receiver.StreamText.Split('\n');
		Assert.Equal(3, lines.Length);
		Assert.EndsWith(" one", lines[0]);
		Assert.EndsWith(" two lf-marker", lines[1]);
		Assert.Equal("", lines[2]);
	}

	[Fact]
	public async Task TcpTls_DeliversToAServerWithAPinnedCertificate()
	{
		await using var receiver = SyslogReceiver.Tls();

		Invoke($"New-Logger | Add-SinkSyslog 'localhost' -Port {receiver.Port} -Protocol TcpTls " +
			$"-TrustedCertificateThumbprint '{receiver.Certificate.Thumbprint}' -BatchInterval 0.1 | Start-Logger; " +
			"Write-InfoLog 'tls-marker'");

		Assert.True(await receiver.WaitForAsync("tls-marker", Delivery));
		Assert.EndsWith(" tls-marker", Assert.Single(receiver.OctetCountedFrames()));
	}

	[Fact]
	public async Task TcpTls_SendsNothingToAnUntrustedServer()
	{
		await using var receiver = SyslogReceiver.Tls();

		Invoke($"New-Logger | Add-SinkSyslog 'localhost' -Port {receiver.Port} -Protocol TcpTls -BatchInterval 0.1 | Start-Logger; " +
			"Write-InfoLog 'untrusted-marker'");

		Assert.False(await receiver.WaitForAsync("untrusted-marker", TimeSpan.FromSeconds(3)));
	}

	[Fact]
	public async Task RestrictedToMinimumLevel_FiltersEvents()
	{
		await using var receiver = SyslogReceiver.Udp();

		Invoke($"New-Logger | Add-SinkSyslog '127.0.0.1' -Port {receiver.Port} -RestrictedToMinimumLevel Warning -BatchInterval 0.1 | Start-Logger; " +
			"Write-InfoLog 'filtered-out'; Write-ErrorLog 'level-marker'");

		Assert.True(await receiver.WaitForAsync("level-marker", Delivery));
		Assert.DoesNotContain(receiver.Datagrams, d => d.Contains("filtered-out"));
	}

	[Fact]
	public async Task AppName_DefaultsToTheCallingScript()
	{
		await using var receiver = SyslogReceiver.Udp();
		var script = Path.Combine(Path.GetTempPath(), $"nightly-backup-{Guid.NewGuid():N}.ps1");
		File.WriteAllText(script, $"New-Logger | Add-SinkSyslog '127.0.0.1' -Port {receiver.Port} -BatchInterval 0.1 | Start-Logger; Write-InfoLog 'app-marker'");
		try
		{
			Invoke($"& '{script}'");

			Assert.True(await receiver.WaitForAsync("app-marker", Delivery));
			Assert.Contains($" {Path.GetFileNameWithoutExtension(script)} ", Assert.Single(receiver.Datagrams));
		}
		finally
		{
			File.Delete(script);
		}
	}

	[Fact]
	public async Task Delivery_DoesNotLoadPeriodicBatching()
	{
		await using var receiver = SyslogReceiver.Tcp();

		Invoke($"New-Logger | Add-SinkSyslog '127.0.0.1' -Port {receiver.Port} -Protocol Tcp -BatchInterval 0.1 | Start-Logger; Write-InfoLog 'pb-marker'");

		Assert.True(await receiver.WaitForAsync("pb-marker", Delivery));
		Assert.DoesNotContain(AppDomain.CurrentDomain.GetAssemblies(), a => a.GetName().Name == "Serilog.Sinks.PeriodicBatching");
	}
}
