namespace PoShLog.UnitTests;

/// <summary>
/// Covers all Write-*Log cmdlets: verbose, debug, info/information, warning, error, fatal.
/// </summary>
public class WriteLogCmdletsTests : PoShLogTestBase
{
    public WriteLogCmdletsTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        Invoke("New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger");
    }

    [Theory]
    [InlineData("Write-VerboseLog", "Test verbose message")]
    [InlineData("Write-DebugLog", "Test debug message")]
    [InlineData("Write-InfoLog", "Test info message")]
    [InlineData("Write-InformationLog", "Test information message")]
    [InlineData("Write-WarningLog", "Test warning message")]
    [InlineData("Write-ErrorLog", "Test error message")]
    [InlineData("Write-FatalLog", "Test fatal message")]
    public void WriteLogCmdlet_DoesNotThrow(string cmdlet, string message)
    {
        Invoke($"{cmdlet} '{message}'");
    }

    [Fact]
    public void WriteInfoLog_IsAliasForWriteInformationLog()
    {
        Invoke("$global:VerbosePreference = 'SilentlyContinue'");
        Invoke("$global:InformationPreference = 'Continue'");

        var infoOutput = Invoke("(Write-InfoLog 'via info') 6>&1");
        var informationOutput = Invoke("(Write-InformationLog 'via information') 6>&1");

        Assert.Contains(infoOutput, r => r.ToString().Contains("via info"));
        Assert.Contains(informationOutput, r => r.ToString().Contains("via information"));
    }

    [Fact]
    public void WriteLogCmdlet_WithPropertyValues_FormatsMessageTemplate()
    {
        Invoke("$global:InformationPreference = 'Continue'");

        var results = Invoke(@"
            $position = @{ Latitude = 25; Longitude = 134 }
            $elapsedMs = 34
            (Write-InfoLog 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs) 6>&1
        ");

        Assert.Contains(results, r => r.ToString().Contains("034 ms"));
    }

    [Fact]
    public void WriteLogCmdlet_WithException_DoesNotThrow()
    {
        Invoke("Write-ErrorLog 'Failure occurred' -Exception ([System.Exception]::new('boom'))");
    }

    [Fact]
    public void WriteLogCmdlet_WithErrorRecord_DoesNotThrow()
    {
        Invoke(@"
            $errorRecord = $null
            try { throw 'boom' } catch { $errorRecord = $_ }
            Write-ErrorLog 'Failure occurred' -ErrorRecord $errorRecord
        ");
    }

    [Fact]
    public void WriteLogCmdlet_WithNullErrorRecord_DoesNotThrow()
    {
        Invoke("Write-ErrorLog 'Failure occurred' -ErrorRecord $null");
    }

    [Fact]
    public void WriteLogCmdlet_WithPassThru_ReturnsFormattedMessage()
    {
        var results = Invoke("Write-InfoLog 'passthru message' -PassThru");

        var formatted = Assert.Single(results);
        Assert.Contains("passthru message", formatted.ToString());
    }

    [Fact]
    public void WriteLogCmdlet_MissingMandatoryMessageTemplate_Throws()
    {
        var results = Invoke("Write-InfoLog -PropertyValues 1,2", allowErrors: true);

        Assert.Empty(results);
        Assert.NotNull(LastException);
    }

    [Fact]
    public void WriteLogCmdlet_EmptyMessageTemplate_DoesNotThrow()
    {
        Invoke("Write-InfoLog ''");
    }

    [Fact]
    public void WriteLogCmdlet_WithExplicitLogger_UsesGivenLoggerInsteadOfGlobal()
    {
        Invoke("$explicitLogger = New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger -PassThru");

        // Should not throw when an explicit logger instance is supplied via -Logger.
        Invoke("Write-InfoLog 'via explicit logger' -Logger $explicitLogger");
    }

    [Fact]
    public void WriteLogCmdlet_ViaPipelineInput_DoesNotThrow()
    {
        Invoke("'piped message' | Write-InfoLog");
    }

    [Fact]
    public void WriteVerboseLog_RespectsVerbosePreference()
    {
        Invoke("$global:VerbosePreference = 'Continue'");
        var written = Invoke("(Write-VerboseLog 'Test verbose message') 4>&1");
        Assert.Contains(written, r => r.ToString().Contains("Test verbose message"));

        Invoke("$global:VerbosePreference = 'SilentlyContinue'");
        var suppressed = Invoke("(Write-VerboseLog 'Test verbose message') 4>&1");
        Assert.Empty(suppressed);
    }
}
