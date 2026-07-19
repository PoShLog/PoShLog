namespace PoShLog.UnitTests;

/// <summary>
/// Covers New-LevelSwitch, Set-LevelSwitch and Set-MinimumLevel (Value / ControlledBy / FromPreference).
/// </summary>
public class LevelSwitchCmdletsTests : PoShLogTestBase
{
    public LevelSwitchCmdletsTests(PoShLogModuleFixture fixture) : base(fixture)
    {
    }

    [Fact]
    public void NewLevelSwitch_DefaultsToInformation()
    {
        var results = Invoke("(New-LevelSwitch).MinimumLevel");

        var level = Assert.Single(results);
        Assert.Equal("Information", level.ToString());
    }

    [Theory]
    [InlineData("Verbose")]
    [InlineData("Debug")]
    [InlineData("Warning")]
    [InlineData("Error")]
    [InlineData("Fatal")]
    public void NewLevelSwitch_WithMinimumLevel_SetsLevel(string level)
    {
        var results = Invoke($"(New-LevelSwitch -MinimumLevel {level}).MinimumLevel");

        Assert.Equal(level, Assert.Single(results).ToString());
    }

    [Fact]
    public void SetLevelSwitch_UpdatesMinimumLevelInPlace()
    {
        Invoke("$switch = New-LevelSwitch -MinimumLevel Information");
        Invoke("Set-LevelSwitch -LevelSwitch $switch -MinimumLevel Error");

        var results = Invoke("$switch.MinimumLevel");
        Assert.Equal("Error", Assert.Single(results).ToString());
    }

    [Fact]
    public void SetLevelSwitch_FromPipeline_UpdatesMinimumLevel()
    {
        Invoke("$switch = New-LevelSwitch");
        Invoke("$switch | Set-LevelSwitch -MinimumLevel Warning");

        var results = Invoke("$switch.MinimumLevel");
        Assert.Equal("Warning", Assert.Single(results).ToString());
    }

    [Fact]
    public void SetLevelSwitch_WithPassThru_ReturnsUpdatedSwitch()
    {
        Invoke("$switch = New-LevelSwitch");
        var results = Invoke("Set-LevelSwitch -LevelSwitch $switch -MinimumLevel Fatal -PassThru");

        var returned = Assert.Single(results);
        Assert.Equal("Serilog.Core.LoggingLevelSwitch", returned.BaseObject.GetType().FullName);
    }

    [Fact]
    public void SetLevelSwitch_MissingMandatoryParameters_Throws()
    {
        var results = Invoke("Set-LevelSwitch", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void SetMinimumLevel_WithValue_DoesNotThrow()
    {
        Invoke("New-Logger | Set-MinimumLevel -Value Warning | Out-Null");
    }

    [Fact]
    public void SetMinimumLevel_ControlledBySwitch_DoesNotThrow()
    {
        Invoke(@"
            $switch = New-LevelSwitch -MinimumLevel Debug
            New-Logger | Set-MinimumLevel -ControlledBy $switch | Out-Null
        ");
    }

    [Fact]
    public void SetMinimumLevel_FromPreference_DoesNotThrow()
    {
        Invoke("$global:VerbosePreference = 'Continue'");
        Invoke("New-Logger | Set-MinimumLevel -FromPreference | Out-Null");
    }

    [Fact]
    public void SetMinimumLevel_MissingLoggerConfig_Throws()
    {
        var results = Invoke("Set-MinimumLevel -Value Warning", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void SetMinimumLevel_NullLevelSwitch_Throws()
    {
        var results = Invoke("New-Logger | Set-MinimumLevel -ControlledBy $null", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void LevelSwitch_DynamicallyControlsLoggingLevel()
    {
        Invoke(@"
            $switch = New-LevelSwitch -MinimumLevel Warning
            New-Logger | Set-MinimumLevel -ControlledBy $switch | Add-SinkPowerShell | Start-Logger
            $global:InformationPreference = 'Continue'
        ");

        var beforeChange = Invoke("(Write-InfoLog 'below threshold') 6>&1");
        Assert.Empty(beforeChange);

        Invoke("$switch | Set-LevelSwitch -MinimumLevel Verbose");

        var afterChange = Invoke("(Write-InfoLog 'above threshold now') 6>&1");
        Assert.Contains(afterChange, r => r.ToString().Contains("above threshold now"));
    }
}
