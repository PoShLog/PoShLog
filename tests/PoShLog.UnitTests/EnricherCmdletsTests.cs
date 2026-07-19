namespace PoShLog.UnitTests;

/// <summary>
/// Covers Add-EnrichFromLogContext, Add-EnrichWithErrorRecord and Add-EnrichWithProperty.
/// </summary>
public class EnricherCmdletsTests : PoShLogTestBase
{
    public EnricherCmdletsTests(PoShLogModuleFixture fixture) : base(fixture)
    {
    }

    [Fact]
    public void AddEnrichFromLogContext_ReturnsLoggerConfiguration()
    {
        var results = Invoke("New-Logger | Add-EnrichFromLogContext");

        var config = Assert.Single(results);
        Assert.Equal("Serilog.LoggerConfiguration", config.BaseObject.GetType().FullName);
    }

    [Fact]
    public void AddEnrichFromLogContext_MissingLoggerConfig_Throws()
    {
        var results = Invoke("Add-EnrichFromLogContext", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void AddEnrichWithProperty_ReturnsLoggerConfiguration()
    {
        var results = Invoke("New-Logger | Add-EnrichWithProperty -Name ScriptName -Value 'Test'");

        var config = Assert.Single(results);
        Assert.Equal("Serilog.LoggerConfiguration", config.BaseObject.GetType().FullName);
    }

    [Fact]
    public void AddEnrichWithProperty_EnrichesLogOutput()
    {
        Invoke(@"
            New-Logger |
            Set-MinimumLevel -Value Verbose |
            Add-EnrichWithProperty -Name ScriptName -Value 'MyScript' |
            Add-SinkPowerShell -OutputTemplate '{Message:lj} {ScriptName}' |
            Start-Logger
        ");
        Invoke("$global:InformationPreference = 'Continue'");

        var results = Invoke("(Write-InfoLog 'enriched message') 6>&1");

        Assert.Contains(results, r => r.ToString().Contains("MyScript"));
    }

    [Fact]
    public void AddEnrichWithProperty_MissingMandatoryParameters_Throws()
    {
        var results = Invoke("New-Logger | Add-EnrichWithProperty", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void AddEnrichWithErrorRecord_ReturnsLoggerConfiguration()
    {
        var results = Invoke("New-Logger | Add-EnrichWithErrorRecord");

        var config = Assert.Single(results);
        Assert.Equal("Serilog.LoggerConfiguration", config.BaseObject.GetType().FullName);
    }

    [Fact]
    public void AddEnrichWithErrorRecord_WithDestructureObjectsSwitch_DoesNotThrow()
    {
        Invoke("New-Logger | Add-EnrichWithErrorRecord -DestructureObjects | Out-Null");
    }

    [Fact]
    public void AddEnrichWithErrorRecord_EnrichesLogWithErrorRecordProperty()
    {
        Invoke(@"
            New-Logger |
            Set-MinimumLevel -Value Verbose |
            Add-EnrichWithErrorRecord |
            Add-SinkPowerShell -OutputTemplate '{Message:lj}{ErrorRecord}' |
            Start-Logger
        ");

        var results = Invoke(@"
            $errorRecord = $null
            try { throw 'boom' } catch { $errorRecord = $_ }
            (Write-ErrorLog 'failed' -ErrorRecord $errorRecord) 6>&1
        ");

        Assert.Contains(results, r => r.ToString().Contains("failed"));
    }
}
