using System.Management.Automation;

namespace PoShLog.UnitTests;

/// <summary>
/// Covers which streams the PowerShell sink writes to (issue #45) and which sinks the short Start-Logger form
/// adds (issue #28); see ADR 0008.
/// </summary>
public class PowerShellSinkStreamTests : PoShLogTestBase
{
    public PowerShellSinkStreamTests(PoShLogModuleFixture fixture) : base(fixture)
    {
    }

    private string[] SinkTypeNames() =>
        Invoke("$sinks = [Serilog.Log]::Logger.GetType().GetField('_sink', 'NonPublic,Instance').GetValue([Serilog.Log]::Logger); " +
               "$inner = $sinks.GetType().GetField('_sinks', 'NonPublic,Instance'); " +
               "if ($inner) { $inner.GetValue($sinks) | ForEach-Object { $_.GetType().Name } } else { $sinks.GetType().Name }")
            .Select(r => r.BaseObject.ToString()!).ToArray();

    [Fact]
    public void StartLogger_Console_AddsOnlyTheConsoleSink()
    {
        Invoke("Start-Logger -Console");

        var sinks = SinkTypeNames();

        Assert.DoesNotContain(sinks, s => s.Contains("PowerShell"));
        Invoke("Write-InfoLog 'once'");
        Assert.Empty(Shell.Streams.Information);
    }

    [Fact]
    public void StartLogger_ConsoleAndPowerShell_AddsBoth()
    {
        Invoke("Start-Logger -Console -PowerShell");
        Invoke("Write-InfoLog 'twice'");

        Assert.Single(Shell.Streams.Information);
    }

    [Fact]
    public void StartLogger_WithoutSinkSwitches_StillDefaultsToPowerShellSink()
    {
        Invoke("Start-Logger");
        Invoke("Write-InfoLog 'default'");

        Assert.Equal("default", Assert.Single(Shell.Streams.Information).MessageData.ToString());
    }

    [Theory]
    [InlineData("Write-ErrorLog")]
    [InlineData("Write-FatalLog")]
    public void ErrorAndFatal_AreHostDisplayedRecords(string cmdlet)
    {
        Invoke("New-Logger | Add-SinkPowerShell | Start-Logger");
        Invoke($"{cmdlet} 'it broke'");

        var record = Assert.Single(Shell.Streams.Information);
        var message = Assert.IsType<HostInformationMessage>(record.MessageData);
        Assert.Equal("it broke", message.Message);
        Assert.Equal(ConsoleColor.Red, message.ForegroundColor);
        Assert.Contains("PSHOST", record.Tags);
        Assert.Equal("PoShLog", record.Source);
        Assert.Empty(Shell.Streams.Error);
    }

    [Fact]
    public void ErrorLog_WithExplicitInformationAction_IsNotForcedToTheHost()
    {
        Invoke("New-Logger | Add-SinkPowerShell | Start-Logger");
        Invoke("Write-ErrorLog 'quiet' -InformationAction SilentlyContinue");

        var record = Assert.Single(Shell.Streams.Information);
        Assert.DoesNotContain("PSHOST", record.Tags);
    }

    [Fact]
    public void ErrorLog_UnderErrorActionStop_DoesNotThrow()
    {
        Invoke("New-Logger | Add-SinkPowerShell | Start-Logger");
        var results = Invoke("$ErrorActionPreference = 'Stop'; Write-ErrorLog 'still running'; 'continued'");

        Assert.Equal("continued", Assert.Single(results).BaseObject);
    }

    [Fact]
    public void InformationLog_StillFollowsInformationPreference()
    {
        Invoke("New-Logger | Add-SinkPowerShell | Start-Logger");
        Invoke("Write-InfoLog 'plain'");

        var record = Assert.Single(Shell.Streams.Information);
        Assert.IsType<string>(record.MessageData);
        Assert.DoesNotContain("PSHOST", record.Tags);
    }
}
