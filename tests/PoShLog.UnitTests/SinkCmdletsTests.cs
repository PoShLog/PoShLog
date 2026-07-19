namespace PoShLog.UnitTests;

/// <summary>
/// Covers Add-SinkConsole, Add-SinkFile and Add-SinkPowerShell.
/// </summary>
public class SinkCmdletsTests : PoShLogTestBase
{
    private readonly string _tempDirectory;

    public SinkCmdletsTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        _tempDirectory = Path.Combine(Path.GetTempPath(), "PoShLogTests_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDirectory);
    }

    [Fact]
    public void AddSinkConsole_ReturnsLoggerConfiguration()
    {
        var results = Invoke("New-Logger | Add-SinkConsole");

        var config = Assert.Single(results);
        Assert.Equal("Serilog.LoggerConfiguration", config.BaseObject.GetType().FullName);
    }

    [Fact]
    public void AddSinkConsole_WithCustomOutputTemplateAndLevel_DoesNotThrow()
    {
        Invoke("New-Logger | Add-SinkConsole -RestrictedToMinimumLevel Warning -OutputTemplate '{Message:lj}' | Start-Logger");
        Invoke("Close-Logger");
    }

    [Fact]
    public void AddSinkConsole_WithJsonFormatter_DoesNotThrow()
    {
        Invoke("New-Logger | Add-SinkConsole -Formatter (Get-JsonFormatter) | Start-Logger");
        Invoke("Close-Logger");
    }

    [Fact]
    public void AddSinkConsole_MissingLoggerConfig_Throws()
    {
        var results = Invoke("Add-SinkConsole", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void AddSinkFile_WritesActualLogFile()
    {
        var path = Path.Combine(_tempDirectory, "test.log");
        Invoke($"New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkFile -Path '{EscapePath(path)}' | Start-Logger");
        Invoke("Write-InfoLog 'file sink message'");
        Invoke("Close-Logger");

        Assert.True(File.Exists(path));
        var content = File.ReadAllText(path);
        Assert.Contains("file sink message", content);
    }

    [Fact]
    public void AddSinkFile_WithJsonFormatter_WritesFile()
    {
        var path = Path.Combine(_tempDirectory, "test-json.log");
        Invoke($"New-Logger | Add-SinkFile -Path '{EscapePath(path)}' -Formatter (Get-JsonFormatter) | Start-Logger");
        Invoke("Write-InfoLog 'json message'");
        Invoke("Close-Logger");

        Assert.True(File.Exists(path));
    }

    [Fact]
    public void AddSinkFile_MissingMandatoryPath_Throws()
    {
        var results = Invoke("New-Logger | Add-SinkFile", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void AddSinkPowerShell_ReturnsLoggerConfiguration()
    {
        var results = Invoke("New-Logger | Add-SinkPowerShell");

        var config = Assert.Single(results);
        Assert.Equal("Serilog.LoggerConfiguration", config.BaseObject.GetType().FullName);
    }

    [Fact]
    public void AddSinkPowerShell_RoutesToInformationStream()
    {
        Invoke("New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger");
        Invoke("$global:InformationPreference = 'Continue'");

        var results = Invoke("(Write-InfoLog 'routed message') 6>&1");

        Assert.Contains(results, r => r.ToString().Contains("routed message"));
    }

    [Fact]
    public void AddSinkPowerShell_RoutesErrorToErrorStream()
    {
        Invoke("New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger");

        var results = Invoke("(Write-ErrorLog 'routed error') 6>&1");

        Assert.Contains(results, r => r.ToString().Contains("routed error"));
    }

    [Fact]
    public void AddSinkPowerShell_WithLevelSwitch_DoesNotThrow()
    {
        Invoke(@"
            $switch = New-LevelSwitch -MinimumLevel Verbose
            New-Logger | Add-SinkPowerShell -LevelSwitch $switch | Start-Logger
        ");
    }

    private static string EscapePath(string path) => path.Replace("'", "''");

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (!disposing)
        {
            return;
        }

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
