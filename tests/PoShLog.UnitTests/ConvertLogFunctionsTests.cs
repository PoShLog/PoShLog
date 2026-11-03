using System.Text;

namespace PoShLog.UnitTests;

public class ConvertLogFunctionsTests : PoShLogTestBase
{
    private readonly string _directory = Path.Combine(Path.GetTempPath(), "PoShLogConvert_" + Guid.NewGuid());
    private string ScriptPath => Path.Combine(_directory, "input.ps1");
    private string QuotedPath => ScriptPath.Replace("'", "''");

    public ConvertLogFunctionsTests(PoShLogModuleFixture fixture) : base(fixture) => Directory.CreateDirectory(_directory);

    [Fact]
    public void ConvertsOnlyCommandsAndPreservesOtherText()
    {
        var text = "# Write-Warning -Message comment\r\n$s = 'Write-Verbose -Message string'\n" +
            "$h = @'\r\nWrite-Debug here-string\r\n'@\r\n" +
            "function Write-Verbose { 'definition' }\n$WriteWarning = 1\n" +
            "wRiTe-WaRnInG -mEs 'hello' # Write-Information comment";
        File.WriteAllText(ScriptPath, text, new UTF8Encoding(false));
        var result = Invoke($"Convert-LogFunctions -Path '{QuotedPath}'");
        var finding = Assert.Single(result);
        Assert.Equal("Converted", finding.Properties["Action"].Value);
        Assert.Equal(text.Replace("wRiTe-WaRnInG -mEs", "Write-WarningLog -MessageTemplate"), File.ReadAllText(ScriptPath));
        Assert.Equal(text, File.ReadAllText(ScriptPath + ".bak"));
    }

    [Theory]
    [InlineData("Write-Error -Message 'failure'", "error semantics")]
    [InlineData("Write-Host 'hello' -ForegroundColor Red", "ForegroundColor")]
    [InlineData("Write-Host 'hello' -NoNewline", "NoNewline")]
    [InlineData("Write-Information 'hello' -Tags tag", "Tags")]
    [InlineData("Write-Warning @arguments", "Splatting")]
    [InlineData("'hello' | Write-Warning", "Pipeline input")]
    [InlineData("Write-Host 'hello' 'world'", "Multiple message")]
    [InlineData("Write-Warning -in Continue 'hello'", "ambiguous")]
    public void UnsafeCallIsSkipped(string text, string reason)
    {
        File.WriteAllText(ScriptPath, text);
        var finding = Assert.Single(Invoke($"Convert-LogFunctions -FilePath '{QuotedPath}'"));
        Assert.Equal("Skipped", finding.Properties["Action"].Value);
        Assert.Contains(reason, (string)finding.Properties["Reason"].Value);
        Assert.Equal(text, File.ReadAllText(ScriptPath));
        Assert.False(File.Exists(ScriptPath + ".bak"));
    }

    [Theory]
    [InlineData("Write-Verbose -Mes:'hello'", "Write-VerboseLog -MessageTemplate:'hello'")]
    [InlineData("Write-Debug 'hello' -ea Stop", "Write-DebugLog 'hello' -ErrorAction Stop")]
    [InlineData("Write-Information -MessageD 'hello'", "Write-InfoLog -MessageTemplate 'hello'")]
    [InlineData("Write-Host -Obj 'hello'", "Write-InfoLog -MessageTemplate 'hello'")]
    public void ConvertsSupportedParameters(string text, string expected)
    {
        File.WriteAllText(ScriptPath, text);
        Assert.Single(Invoke($"Get-Item -LiteralPath '{QuotedPath}' | Convert-LogFunctions"));
        Assert.Equal(expected, File.ReadAllText(ScriptPath));
    }

    [Fact]
    public void WhatIfDoesNotWriteOrBackUp()
    {
        var bytes = Encoding.UTF8.GetBytes("Write-Warning 'hello'");
        File.WriteAllBytes(ScriptPath, bytes);
        var finding = Assert.Single(Invoke($"Convert-LogFunctions -Path '{QuotedPath}' -WhatIf"));
        Assert.Equal(bytes, File.ReadAllBytes(ScriptPath));
        Assert.False(File.Exists(ScriptPath + ".bak"));
        Assert.Equal("Skipped", finding.Properties["Action"].Value);
        Assert.Contains("Write-WarningLog", (string)finding.Properties["After"].Value);
    }

    [Theory]
    [InlineData("utf8bom")]
    [InlineData("utf8")]
    [InlineData("utf16le")]
    [InlineData("utf16be")]
    [InlineData("utf32")]
    public void PreservesEncodingBomAndLineEndingsAndBacksUpOriginal(string kind)
    {
        Encoding encoding = kind switch
        {
            "utf8bom" => new UTF8Encoding(true), "utf8" => new UTF8Encoding(false),
            "utf16le" => Encoding.Unicode, "utf16be" => Encoding.BigEndianUnicode, _ => Encoding.UTF32
        };
        var text = "# café 😀\r\nWrite-Warning 'žluťoučký'\nWrite-Debug 'ok'";
        var original = encoding.GetPreamble().Concat(encoding.GetBytes(text)).ToArray();
        File.WriteAllBytes(ScriptPath, original);
        Invoke($"Convert-LogFunctions -Path '{QuotedPath}'");
        var expected = encoding.GetPreamble().Concat(encoding.GetBytes(text.Replace("Write-Warning", "Write-WarningLog").Replace("Write-Debug", "Write-DebugLog"))).ToArray();
        Assert.Equal(expected, File.ReadAllBytes(ScriptPath));
        Assert.Equal(original, File.ReadAllBytes(ScriptPath + ".bak"));
    }

    [Fact]
    public void ParseErrorRefusesEntireFile()
    {
        var text = "Write-Warning 'hello'\nif (";
        File.WriteAllText(ScriptPath, text);
        Assert.Empty(Invoke($"Convert-LogFunctions -Path '{QuotedPath}'", allowErrors: true));
        Assert.Contains(Shell.Streams.Error, e => e.FullyQualifiedErrorId.StartsWith("LogConversionParseError"));
        Assert.Equal(text, File.ReadAllText(ScriptPath));
        Assert.False(File.Exists(ScriptPath + ".bak"));
    }

    [Fact]
    public void ExistingBackupRequiresForce()
    {
        var text = "Write-Warning 'hello'";
        File.WriteAllText(ScriptPath, text);
        File.WriteAllText(ScriptPath + ".bak", "previous backup");
        Assert.Empty(Invoke($"Convert-LogFunctions -Path '{QuotedPath}'", allowErrors: true));
        Assert.NotNull(LastException);
        Assert.Equal(text, File.ReadAllText(ScriptPath));
        Assert.Equal("previous backup", File.ReadAllText(ScriptPath + ".bak"));
        Invoke($"Convert-LogFunctions -Path '{QuotedPath}' -Force");
        Assert.Equal(text, File.ReadAllText(ScriptPath + ".bak"));
        Assert.Equal("Write-WarningLog 'hello'", File.ReadAllText(ScriptPath));
    }

    [Fact]
    public void CommandsInsideExpandableStringsStayUntouched()
    {
        var text = "$s = \"$(Write-Warning 'embedded')\"\n$h = @\"\n$(Write-Debug 'embedded')\n\"@";
        File.WriteAllText(ScriptPath, text);
        var findings = Invoke($"Convert-LogFunctions -Path '{QuotedPath}'");
        Assert.Equal(2, findings.Count);
        Assert.All(findings, f => Assert.Equal("Skipped", f.Properties["Action"].Value));
        Assert.Equal(text, File.ReadAllText(ScriptPath));
        Assert.False(File.Exists(ScriptPath + ".bak"));
    }

    [Fact]
    public void MixedCallsReportEveryFindingInSourceOrder()
    {
        File.WriteAllText(ScriptPath, "Write-Error 'one'\nWrite-Warning 'two'; Write-Error 'three'");
        var findings = Invoke($"Convert-LogFunctions -Path '{QuotedPath}' -Confirm:$false");
        Assert.Equal(new[] { "Skipped", "Converted", "Skipped" }, findings.Select(f => (string)f.Properties["Action"].Value));
        Assert.Equal(new[] { 1, 2, 2 }, findings.Select(f => (int)f.Properties["Line"].Value));
        Assert.Equal("Write-Error 'one'\nWrite-WarningLog 'two'; Write-Error 'three'", File.ReadAllText(ScriptPath));
    }

    [Fact]
    public void InvalidEncodingRefusesWithoutChangingBytes()
    {
        var bytes = Encoding.UTF8.GetBytes("Write-Warning 'hello' # ").Concat(new byte[] { 0xff }).ToArray();
        File.WriteAllBytes(ScriptPath, bytes);
        Assert.Empty(Invoke($"Convert-LogFunctions -Path '{QuotedPath}'", allowErrors: true));
        Assert.NotNull(LastException);
        Assert.Equal(bytes, File.ReadAllBytes(ScriptPath));
        Assert.False(File.Exists(ScriptPath + ".bak"));
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing)
        {
            foreach (var file in Directory.GetFiles(_directory)) File.Delete(file);
            Directory.Delete(_directory);
        }
    }
}
