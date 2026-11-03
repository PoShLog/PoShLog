using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;
using System.Text.Json;
using Serilog.Debugging;

namespace PoShLog.Sinks.Elastic.Tests;

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class LoggerCollection
{
	// Start-Logger sets the process-wide [Serilog.Log]::Logger and SelfLog is process-wide too, so these tests run one at a time.
	public const string Name = "Serilog global logger";
}

/// <summary>
/// Runs Add-SinkElasticsearch in a PowerShell runspace with Core and the compiled cmdlet imported, against a local
/// Elasticsearch stand-in.
/// </summary>
[Collection(LoggerCollection.Name)]
public sealed class AddSinkElasticsearchTests : IAsyncLifetime
{
	private const string Key = "cG9zaGxvZzpwbGFjZWhvbGRlcg==";
	private static readonly TimeSpan Delivery = TimeSpan.FromSeconds(20);
	private ElasticsearchReceiver _receiver = null!;
	private PowerShell _shell = null!;

	public async Task InitializeAsync()
	{
		_receiver = await ElasticsearchReceiver.StartAsync($"ApiKey {Key}");
		var state = InitialSessionState.CreateDefault();
		if (OperatingSystem.IsWindows())
		{
			state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
		}
		var runspace = RunspaceFactory.CreateRunspace(state);
		runspace.Open();
		_shell = PowerShell.Create(runspace);
		Invoke($"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Core.dll")}' -ErrorAction Stop; " +
			$"Import-Module '{Path.Combine(AppContext.BaseDirectory, "PoShLog.Sinks.Elastic.dll")}' -ErrorAction Stop");
	}

	public async Task DisposeAsync()
	{
		try
		{
			Invoke("Close-Logger", allowErrors: true);
		}
		finally
		{
			SelfLog.Disable();
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

	private string ErrorOf(string script) => Assert.ThrowsAny<Exception>(() => Invoke(script)).Message;

	private string Sink(string arguments = "") => $"New-Logger | Add-SinkElasticsearch -Node '{_receiver.Url}' -ApiKey '{Key}' -BatchInterval 1 {arguments}";

	/// <summary>The documents of a bulk request: every second line, after its action line.</summary>
	private static List<JsonElement> Documents(ElasticsearchRequest request)
	{
		var lines = request.Body.Split('\n', StringSplitOptions.RemoveEmptyEntries);
		var documents = new List<JsonElement>();
		for (var i = 0; i + 1 < lines.Length; i += 2)
		{
			Assert.Equal("{\"create\":{}}", lines[i]);
			documents.Add(JsonDocument.Parse(lines[i + 1]).RootElement);
		}
		return documents;
	}

	[Fact]
	public void ReturnsTheLoggerConfiguration()
	{
		var result = Assert.Single(Invoke(Sink()));

		Assert.Equal("Serilog.LoggerConfiguration", result.BaseObject.GetType().FullName);
	}

	[Theory]
	[InlineData("-DataStream 'logs-poshlog'", "not a data stream name")]
	[InlineData("-DataStream 'Logs-poshlog-default'", "not a data stream name")]
	[InlineData("-CertificateFingerprint 'abc'", "not a SHA-256 certificate fingerprint")]
	[InlineData("-BatchInterval 0.5", "BatchInterval must be at least 1 second")]
	[InlineData("-IlmPolicy 'logs'", "add -BootstrapMethod Silent or Failure")]
	[InlineData("-Credential ([pscredential]::new('elastic', (ConvertTo-SecureString 'x' -AsPlainText -Force)))", "either -ApiKey or -Credential")]
	public void InvalidOptions_FailWithAClearError(string arguments, string expected)
	{
		Assert.Contains(expected, ErrorOf($"New-Logger | Add-SinkElasticsearch -Node '{_receiver.Url}' -ApiKey '{Key}' {arguments}"));
	}

	[Fact]
	public void ANodeThatIsNotHttp_FailsWithAClearError()
	{
		Assert.Contains("not an absolute http or https URL", ErrorOf("New-Logger | Add-SinkElasticsearch -Node 'ftp://es.example.com'"));
	}

	[Fact]
	public void CloudIdWithoutCredentials_FailsWithAClearError()
	{
		Assert.Contains("-CloudId needs -ApiKey or -Credential", ErrorOf("New-Logger | Add-SinkElasticsearch -CloudId 'poshlog:ZXhhbXBsZS5jb20kYWJjJGRlZg=='"));
	}

	[Fact]
	public void CloudIdWithAnApiKey_ConfiguresTheSink()
	{
		var result = Assert.Single(Invoke($"New-Logger | Add-SinkElasticsearch -CloudId 'poshlog:ZXhhbXBsZS5jb20kYWJjJGRlZg==' -ApiKey '{Key}'"));

		Assert.Equal("Serilog.LoggerConfiguration", result.BaseObject.GetType().FullName);
	}

	[Fact]
	public void TheThirdPartyUriParameter_StillBinds()
	{
		Assert.Single(Invoke($"New-Logger | Add-SinkElasticsearch -Uri '{_receiver.Url}' -ApiKey '{Key}'"));
	}

	[Fact]
	public void BulkRequest_CarriesAnEcsDocumentToTheDefaultDataStream()
	{
		Invoke(Sink() + " | Start-Logger; Write-WarningLog 'Backed up {Count} databases for {User} ecs-marker' -PropertyValues 12, 'tomas'");

		var request = _receiver.WaitForBulk("ecs-marker", Delivery);
		Assert.Equal("/logs-poshlog-default/_bulk", request.Path);
		Assert.Equal($"ApiKey {Key}", request.Headers["authorization"]);
		var document = Assert.Single(Documents(request));
		Assert.True(document.TryGetProperty("@timestamp", out _));
		Assert.Equal("Warning", document.GetProperty("log.level").GetString());
		Assert.Equal("Backed up 12 databases for \"tomas\" ecs-marker", document.GetProperty("message").GetString());
		Assert.True(document.TryGetProperty("ecs.version", out _));
		Assert.Equal("tomas", document.GetProperty("labels").GetProperty("User").GetString());
		Assert.True(document.TryGetProperty("host", out _));
		Assert.True(document.TryGetProperty("user", out _));
	}

	[Fact]
	public void ProductCheck_RunsBeforeTheFirstBulkRequest()
	{
		Invoke(Sink() + " | Start-Logger; Write-InfoLog 'order-marker'");

		_receiver.WaitForBulk("order-marker", Delivery);
		var first = _receiver.Log.First();
		Assert.Equal(("HEAD", "/"), (first.Method, first.Path));
	}

	[Fact]
	public void DataStream_ChoosesTheTarget()
	{
		Invoke(Sink("-DataStream 'logs-backup-production'") + " | Start-Logger; Write-InfoLog 'stream-marker'");

		Assert.Equal("/logs-backup-production/_bulk", _receiver.WaitForBulk("stream-marker", Delivery).Path);
	}

	[Fact]
	public async Task Credential_SendsBasicAuthentication()
	{
		var basic = "Basic " + Convert.ToBase64String(Encoding.UTF8.GetBytes("elastic:placeholder"));
		await using var receiver = await ElasticsearchReceiver.StartAsync(basic);

		Invoke($"New-Logger | Add-SinkElasticsearch -Node '{receiver.Url}' -BatchInterval 1 " +
			"-Credential ([pscredential]::new('elastic', (ConvertTo-SecureString 'placeholder' -AsPlainText -Force))) | Start-Logger; " +
			"Write-InfoLog 'basic-marker'; Close-Logger");

		Assert.Equal(basic, receiver.WaitForBulk("basic-marker", Delivery).Headers["authorization"]);
	}

	[Fact]
	public void Exclude_LeavesIdentifyingFieldsOut()
	{
		Invoke(Sink("-ExcludeHost -ExcludeProcess -ExcludeUser") + " | Start-Logger; Write-InfoLog 'exclude-marker'");

		var document = Assert.Single(Documents(_receiver.WaitForBulk("exclude-marker", Delivery)));
		Assert.False(document.TryGetProperty("host", out _));
		Assert.False(document.TryGetProperty("process", out _));
		Assert.False(document.TryGetProperty("user", out _));
	}

	[Fact]
	public void RestrictedToMinimumLevel_FiltersEvents()
	{
		Invoke(Sink("-RestrictedToMinimumLevel Warning") + " | Start-Logger; Write-InfoLog 'filtered-out'; Write-ErrorLog 'level-marker'");

		var request = _receiver.WaitForBulk("level-marker", Delivery);
		Assert.DoesNotContain("filtered-out", request.Body);
	}

	[Fact]
	public void BootstrapMethodSilent_InstallsTemplatesBeforeWriting()
	{
		Invoke(Sink("-BootstrapMethod Silent") + " | Start-Logger; Write-InfoLog 'bootstrap-marker'");

		_receiver.WaitForBulk("bootstrap-marker", Delivery);
		Assert.Contains(_receiver.Log, r => r.Method == "PUT" && r.Path.StartsWith("/_index_template/"));
	}

	[Fact]
	public void BootstrapMethodNone_InstallsNothing()
	{
		Invoke(Sink() + " | Start-Logger; Write-InfoLog 'none-marker'");

		_receiver.WaitForBulk("none-marker", Delivery);
		Assert.DoesNotContain(_receiver.Log, r => r.Method == "PUT");
	}

	[Fact]
	public void AWrongApiKey_IsReportedToSelfLog()
	{
		var messages = new StringWriter();
		SelfLog.Enable(TextWriter.Synchronized(messages));

		Invoke($"New-Logger | Add-SinkElasticsearch -Node '{_receiver.Url}' -ApiKey 'd3Jvbmc=' -BatchInterval 1 | Start-Logger; " +
			"Write-InfoLog 'unauthorized-marker'; Close-Logger");

		var text = messages.ToString();
		Assert.True(text.Contains("Could not authenticate"), text);
	}

	[Fact]
	public void RejectedDocuments_AreReportedToSelfLog()
	{
		var messages = new StringWriter();
		SelfLog.Enable(TextWriter.Synchronized(messages));
		_receiver.RejectDocuments = true;

		Invoke(Sink() + " | Start-Logger; Write-InfoLog 'rejected-marker'; Close-Logger");

		Assert.Contains("stand-in rejects documents", messages.ToString());
	}

	[Fact]
	public void CloseLogger_FlushesQueuedEvents()
	{
		Invoke($"New-Logger | Add-SinkElasticsearch -Node '{_receiver.Url}' -ApiKey '{Key}' -BatchInterval 60 | Start-Logger; " +
			"Write-InfoLog 'flush-marker'; Close-Logger");

		_receiver.WaitForBulk("flush-marker", TimeSpan.FromSeconds(1));
	}
}
