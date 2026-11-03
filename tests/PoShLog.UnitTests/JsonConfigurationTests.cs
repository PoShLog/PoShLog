using Serilog;
using Serilog.Sinks.SystemConsole.Themes;

namespace PoShLog.UnitTests;

public class JsonConfigurationTests(PoShLogModuleFixture fixture) : PoShLogTestBase(fixture)
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "PoShLogIssues_" + Guid.NewGuid());

    private string Prepare()
    {
        Directory.CreateDirectory(directory);
        return directory.Replace("'", "''");
    }

    [Fact]
    public void JsonConfiguration_ConfiguresCoreFileSink()
    {
        var path = Prepare();
        File.WriteAllText(Path.Combine(directory, "sink.json"), System.Text.Json.JsonSerializer.Serialize(new
        {
            Serilog = new { WriteTo = new[] { new { Name = "File", Args = new { path = "./configured.log", outputTemplate = "{Message:lj}{NewLine}" } } } }
        }));
        Invoke($"Set-Location '{path}'; New-Logger -ConfigurationPath './sink.json' | Start-Logger; Write-InfoLog 'configured sink'; Close-Logger");
        Assert.Equal("configured sink" + Environment.NewLine, File.ReadAllText(Path.Combine(directory, "configured.log")));
    }

    [Fact]
    public void JsonConfiguration_MissingFileFails()
    {
        var path = Prepare();
        Invoke($"New-Logger -ConfigurationPath '{path}/missing.json'", allowErrors: true);
        Assert.IsType<FileNotFoundException>(LastException?.InnerException ?? LastException);
    }

    [Fact]
    public void JsonConfiguration_ReleasesSinksWhenLaterConfigurationFails()
    {
        var path = Prepare();
        File.WriteAllText(Path.Combine(directory, "partial.json"), System.Text.Json.JsonSerializer.Serialize(new
        {
            Serilog = new { WriteTo = new object[] {
                new { Name = "File", Args = new { path = Path.Combine(directory, "partial.log") } },
                new { Name = "UnknownSink" }
            } }
        }));
        Invoke($"New-Logger -ConfigurationPath '{path}/partial.json'", allowErrors: true);
        Assert.NotNull(LastException);
        using var file = new FileStream(Path.Combine(directory, "partial.log"), FileMode.Open, FileAccess.ReadWrite, FileShare.None);
        Assert.True(file.CanRead);
    }

    [Fact]
    public void JsonConfiguration_LoadsRelativeFile_AndComposesWithPipeline()
    {
        var path = Prepare();
        File.WriteAllText(Path.Combine(directory, "logging.json"), """
            { "Serilog": { "MinimumLevel": "Warning", "Properties": { "Application": "json-test" } } }
            """);
        Invoke($$"""
            Set-Location '{{path}}'
            New-Logger -ConfigurationPath './logging.json' |
                Add-SinkFile -Path './json.log' -OutputTemplate '{Application} {Message:lj}{NewLine}' | Start-Logger
            Write-InfoLog 'excluded'
            Write-WarningLog 'included'
            Close-Logger
            """);
        Assert.Equal("json-test included" + Environment.NewLine, File.ReadAllText(Path.Combine(directory, "json.log")));
    }

    [Theory]
    [InlineData("{")]
    [InlineData("{}")]
    [InlineData("{\"Serilog\":{\"MinimumLevel\":\"WrongLevel\"}}")]
    [InlineData("{\"Serilog\":{\"WriteTo\":[\"UnknownSink\"]}}")]
    [InlineData("{\"Serilog\":{\"WriteTo\":[{\"Name\":\"File\",\"Args\":{\"wrongArgument\":true}}]}}")]
    [InlineData("{\"Serilog\":{\"Using\":[\"NotLoaded\"]}}")]
    [InlineData("{\"Serilog\":{\"LevelSwitches\":{}}}")]
    public void JsonConfiguration_RejectsInvalidConfiguration(string json)
    {
        var path = Prepare();
        File.WriteAllText(Path.Combine(directory, "invalid.json"), json);
        Invoke($"New-Logger -ConfigurationPath '{path}/invalid.json'", allowErrors: true);
        Assert.NotNull(LastException);
        Assert.DoesNotContain("parameter name", LastException!.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void JsonConfiguration_BindsFilterAndEnrichment_AndMinimumOverrides()
    {
        var path = Prepare();
        File.WriteAllText(Path.Combine(directory, "filter.json"), """
            { "Serilog": {
                "MinimumLevel": { "Default": "Warning", "Override": { "Special": "Information" } },
                "Properties": { "Details": { "Count": 2 }, "Enabled": true },
                "Enrich": ["FromLogContext"],
                "Filter": [{ "Name": "ByIncludingOnly", "Args": { "expression": "Accept = true" } }]
            } }
            """);
        Invoke($$"""
            New-Logger -ConfigurationPath '{{path}}/filter.json' |
                Add-SinkFile -Path '{{path}}/filter.log' -OutputTemplate '{Message:lj} {Details} {Enabled}{NewLine}' | Start-Logger
            Write-WarningLog 'selected {Accept}' -PropertyValues $true
            Write-WarningLog 'excluded {Accept}' -PropertyValues $false
            $special = (Get-Logger).ForContext('SourceContext', 'Special')
            $special.Information('override {Accept}', $true)
            Close-Logger
            """);
        var lines = File.ReadAllLines(Path.Combine(directory, "filter.log"));
        Assert.Equal(2, lines.Length);
        Assert.Contains("selected true", lines[0]);
        Assert.Contains("override true", lines[1]);
        Assert.Contains("Count", lines[0]);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }
}
