namespace PoShLog.UnitTests;

public class CoreCmdletsTests : PoShLogTestBase
{
    public CoreCmdletsTests(PoShLogModuleFixture fixture) : base(fixture)
    {
    }

    [Fact]
    public void NewLogger_ReturnsLoggerConfiguration()
    {
        var results = Invoke("New-Logger");

        var config = Assert.Single(results);
        Assert.Equal("Serilog.LoggerConfiguration", config.BaseObject.GetType().FullName);
    }

    [Fact]
    public void StartLogger_WithNoParameters_SetsDefaultLogger()
    {
        Invoke("Start-Logger");

        var results = Invoke("Get-Logger");
        var logger = Assert.Single(results);
        Assert.Equal("Serilog.Core.Logger", logger.BaseObject.GetType().FullName);
    }

    [Fact]
    public void StartLogger_WithLoggerConfigPipeline_ConfiguresLogger()
    {
        Invoke("New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger");

        var results = Invoke("Get-Logger");
        var logger = Assert.Single(results);
        Assert.Equal("Serilog.Core.Logger", logger.BaseObject.GetType().FullName);
    }

    [Fact]
    public void StartLogger_WithPassThru_ReturnsLoggerWithoutSettingGlobal()
    {
        var results = Invoke("New-Logger | Start-Logger -PassThru");

        var logger = Assert.Single(results);
        Assert.Equal("Serilog.Core.Logger", logger.BaseObject.GetType().FullName);

        // Global logger should remain the untouched Serilog.Log default (SilentLogger), since PassThru
        // without -SetAsDefault should not assign [Serilog.Log]::Logger.
        var globalLogger = Assert.Single(Invoke("Get-Logger"));
        Assert.NotEqual("Serilog.Core.Logger", globalLogger.BaseObject.GetType().FullName);
    }

    [Fact]
    public void StartLogger_WithPassThruAndSetAsDefault_SetsGlobalLogger()
    {
        var results = Invoke("New-Logger | Start-Logger -PassThru -SetAsDefault");

        var logger = Assert.Single(results);
        var globalLogger = Assert.Single(Invoke("Get-Logger"));
        Assert.Equal(logger.BaseObject, globalLogger.BaseObject);
    }

    [Fact]
    public void GetLogger_BeforeStart_ReturnsSilentLogger()
    {
        var results = Invoke("Get-Logger");

        var logger = Assert.Single(results);
        Assert.NotEqual("Serilog.Core.Logger", logger.BaseObject.GetType().FullName);
    }

    [Fact]
    public void SetLogger_WithExplicitLogger_UpdatesGlobalLogger()
    {
        Invoke("$logger = New-Logger | Start-Logger -PassThru");
        Invoke("Set-Logger -Logger $logger");

        var globalLogger = Assert.Single(Invoke("Get-Logger"));
        var directLogger = Assert.Single(Invoke("$logger"));
        Assert.Equal(directLogger.BaseObject, globalLogger.BaseObject);
    }

    [Fact]
    public void SetLogger_FromPipeline_UpdatesGlobalLogger()
    {
        Invoke("New-Logger | Start-Logger -PassThru | Set-Logger");

        var globalLogger = Assert.Single(Invoke("Get-Logger"));
        Assert.Equal("Serilog.Core.Logger", globalLogger.BaseObject.GetType().FullName);
    }

    [Fact]
    public void SetLogger_WithNullLogger_Throws()
    {
        var results = Invoke("Set-Logger -Logger $null", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void SetLogger_MissingMandatoryParameter_Throws()
    {
        var results = Invoke("Set-Logger", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void CloseLogger_WithoutArguments_ResetsGlobalLogger()
    {
        Invoke("Start-Logger");
        Invoke("Close-Logger");

        var logger = Assert.Single(Invoke("Get-Logger"));
        Assert.NotEqual("Serilog.Core.Logger", logger.BaseObject.GetType().FullName);
    }

    [Fact]
    public void CloseLogger_WithExplicitLoggerFromPipeline_DisposesGivenLogger()
    {
        Invoke("$logger = New-Logger | Start-Logger -PassThru");

        // Should not throw when disposing an explicitly provided logger via the pipeline.
        Invoke("$logger | Close-Logger");
    }

    [Fact]
    public void CloseLogger_CalledTwice_DoesNotThrow()
    {
        Invoke("Start-Logger");
        Invoke("Close-Logger");

        // Calling Close-Logger again on an already-closed/default logger should be safe.
        Invoke("Close-Logger");
    }

    [Fact]
    public void NewLogger_PipedThroughFullChain_DoesNotThrow()
    {
        Invoke(@"
            New-Logger |
            Set-MinimumLevel -Value Verbose |
            Add-SinkPowerShell |
            Start-Logger
        ");

        Invoke("Close-Logger");
    }
}
