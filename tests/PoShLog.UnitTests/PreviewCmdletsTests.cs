namespace PoShLog.UnitTests;

/// <summary>
/// Covers the cmdlets ported from the 2.2.0-preview1 feature set: Get-CurrentLogFiles,
/// Set-DefaultMessageFormatter, Enable-SelfLog, Disable-SelfLog and Add-SinkLogger.
/// </summary>
public class PreviewCmdletsTests : PoShLogTestBase
{
    private readonly string _tempDirectory;

    public PreviewCmdletsTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        _tempDirectory = Path.Combine(Path.GetTempPath(), "PoShLogTests_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDirectory);
    }

    [Fact]
    public void GetCurrentLogFiles_WithFileSink_ReturnsThePath()
    {
        var path = Path.Combine(_tempDirectory, "current.log");
        Invoke($"New-Logger | Add-SinkFile -Path '{EscapePath(path)}' | Start-Logger");

        var results = Invoke("Get-CurrentLogFiles");

        Assert.Single(results);
        Assert.Equal(path, results[0].BaseObject.ToString(), ignoreCase: true);
    }

    [Fact]
    public void GetCurrentLogFiles_WithExplicitLogger_ReturnsThePath()
    {
        var path = Path.Combine(_tempDirectory, "explicit.log");
        Invoke($"New-Logger | Add-SinkFile -Path '{EscapePath(path)}' | Start-Logger");

        var results = Invoke("Get-Logger | Get-CurrentLogFiles");

        Assert.Single(results);
    }

    [Fact]
    public void GetCurrentLogFiles_NoFileSink_ReturnsEmpty()
    {
        Invoke("New-Logger | Add-SinkConsole | Start-Logger");

        var results = Invoke("Get-CurrentLogFiles");

        Assert.Empty(results);
    }

    [Fact]
    public void SetDefaultMessageFormatter_ChangesPassThruOutput()
    {
        Invoke("New-Logger | Add-SinkConsole | Start-Logger");
        Invoke("Set-DefaultMessageFormatter -Template '>>{Message:lj}<<'");

        var results = Invoke("Write-InfoLog -MessageTemplate 'hello' -PassThru");

        var message = Assert.Single(results);
        Assert.Equal(">>hello<<", message.BaseObject.ToString());
    }

    [Fact]
    public void SetDefaultMessageFormatter_MissingMandatoryTemplate_Throws()
    {
        var results = Invoke("Set-DefaultMessageFormatter", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void EnableSelfLog_WithCustomCallback_InvokesCallback()
    {
        Invoke(@"
            $script:selfLogMessages = [System.Collections.Generic.List[string]]::new()
            $callback = [System.Action[string]] { param($msg) $script:selfLogMessages.Add($msg) }
            Enable-SelfLog -MessageFunc $callback
            [Serilog.Debugging.SelfLog]::WriteLine('test self log message')
        ");

        var results = Invoke("$script:selfLogMessages");

        Assert.Contains(results, r => r.ToString().Contains("test self log message"));
    }

    [Fact]
    public void EnableSelfLog_WithoutCallback_DoesNotThrow()
    {
        Invoke("Enable-SelfLog");
        Invoke("[Serilog.Debugging.SelfLog]::WriteLine('default callback message')");
    }

    [Fact]
    public void DisableSelfLog_DoesNotThrow()
    {
        Invoke("Enable-SelfLog");
        Invoke("Disable-SelfLog");
    }

    [Fact]
    public void AddSinkLogger_ReturnsLoggerConfiguration()
    {
        var results = Invoke(@"
            $subLogger = New-Logger | Add-SinkConsole | Start-Logger -PassThru
            New-Logger | Add-SinkLogger -Logger $subLogger
        ");

        var config = Assert.Single(results);
        Assert.Equal("Serilog.LoggerConfiguration", config.BaseObject.GetType().FullName);
    }

    [Fact]
    public void AddSinkLogger_RoutesEventsToSubLogger()
    {
        var path = Path.Combine(_tempDirectory, "sublogger.log");
        Invoke($@"
            $script:subLogger = New-Logger | Add-SinkFile -Path '{EscapePath(path)}' | Start-Logger -PassThru
            New-Logger | Add-SinkLogger -Logger $script:subLogger | Start-Logger
        ");
        Invoke("Write-InfoLog 'routed to sub logger'");
        Invoke("Close-Logger");
        Invoke("$script:subLogger | Close-Logger");

        Assert.True(File.Exists(path));
        Assert.Contains("routed to sub logger", File.ReadAllText(path));
    }

    [Fact]
    public void AddSinkLogger_MissingMandatoryLogger_Throws()
    {
        var results = Invoke("New-Logger | Add-SinkLogger", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void AddSinkLogger_MissingLoggerConfig_Throws()
    {
        var results = Invoke(@"
            $subLogger = New-Logger | Add-SinkConsole | Start-Logger -PassThru
            Add-SinkLogger -Logger $subLogger
        ", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    private static string EscapePath(string path) => path.Replace("'", "''");

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (!disposing)
        {
            return;
        }

        // Set-DefaultMessageFormatter and Enable/Disable-SelfLog mutate process-wide static
        // state (PoShLog.Core.Utils.MessageFormatter.TextFormatter / Serilog's SelfLog), so
        // reset them here to avoid leaking into other test classes sharing this collection.
        PoShLog.Core.Utils.MessageFormatter.TextFormatter = null;
        Serilog.Debugging.SelfLog.Disable();

        try
        {
            if (Directory.Exists(_tempDirectory))
            {
                Directory.Delete(_tempDirectory, recursive: true);
            }
        }
        catch
        {
            // best effort cleanup
        }
    }
}
