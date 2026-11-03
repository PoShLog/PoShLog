using System.Diagnostics;
using System.Text.Json;
using Serilog.Events;
using Serilog.Parsing;
using PoShLogCompact = PoShLog.Core.Formatting.CompactJsonFormatter;
using Reference = Serilog.Formatting.Compact;

namespace PoShLog.UnitTests;

/// <summary>
/// Covers Get-CompactFormatter and PoShLog's CLEF formatter (issue #48, ADR 0007). The formatter must write
/// exactly what Serilog.Formatting.Compact writes; that package is referenced by the tests only.
/// </summary>
public class CompactFormatterTests : PoShLogTestBase
{
    private readonly string _tempDirectory;

    public CompactFormatterTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        _tempDirectory = Path.Combine(Path.GetTempPath(), "PoShLogTests_" + Guid.NewGuid());
        Directory.CreateDirectory(_tempDirectory);
    }

    public static TheoryData<string> Events => new()
    {
        "plain",
        "warning-with-exception",
        "format-specifiers",
        "at-property",
        "structures",
        "trace",
        "escaping",
    };

    private static LogEvent CreateEvent(string name)
    {
        var parser = new MessageTemplateParser();
        var timestamp = new DateTimeOffset(2026, 11, 3, 10, 15, 30, 123, TimeSpan.FromHours(1));
        LogEvent Make(LogEventLevel level, string template, Exception? exception, params LogEventProperty[] properties) =>
            new(timestamp, level, exception, parser.Parse(template), properties);

        return name switch
        {
            "plain" => Make(LogEventLevel.Information, "Hello {Name}", null, new LogEventProperty("Name", new ScalarValue("World"))),
            "warning-with-exception" => Make(LogEventLevel.Warning, "Failed", new InvalidOperationException("nope")),
            "format-specifiers" => Make(LogEventLevel.Debug, "Took {Elapsed:000} ms at {When:yyyy-MM-dd} for {Who}", null,
                new LogEventProperty("Elapsed", new ScalarValue(34)),
                new LogEventProperty("When", new ScalarValue(new DateTime(2026, 1, 2))),
                new LogEventProperty("Who", new ScalarValue("me"))),
            "at-property" => Make(LogEventLevel.Error, "Reserved", null, new LogEventProperty("@x", new ScalarValue("user value"))),
            "structures" => Make(LogEventLevel.Fatal, "Got {@Item}", null,
                new LogEventProperty("Item", new StructureValue(new[]
                {
                    new LogEventProperty("Id", new ScalarValue(7)),
                    new LogEventProperty("Tags", new SequenceValue(new[] { new ScalarValue("a"), new ScalarValue("b") })),
                }, "Thing")),
                new LogEventProperty("Map", new DictionaryValue(new[] { new KeyValuePair<ScalarValue, LogEventPropertyValue>(new ScalarValue("k"), new ScalarValue(1.5)) }))),
            "trace" => new LogEvent(timestamp, LogEventLevel.Information, null, parser.Parse("Traced"), Array.Empty<LogEventProperty>(),
                ActivityTraceId.CreateFromString("0af7651916cd43dd8448eb211c80319c"), ActivitySpanId.CreateFromString("b7ad6b7169203331")),
            "escaping" => Make(LogEventLevel.Verbose, "Quote \"{Text}\"\n", null, new LogEventProperty("Text", new ScalarValue("tab\there é"))),
            _ => throw new ArgumentOutOfRangeException(nameof(name)),
        };
    }

    private static string FormatWith(Serilog.Formatting.ITextFormatter formatter, LogEvent logEvent)
    {
        using var writer = new StringWriter();
        formatter.Format(logEvent, writer);
        return writer.ToString();
    }

    [Theory]
    [MemberData(nameof(Events))]
    public void Compact_MatchesSerilogFormattingCompact(string name)
    {
        var logEvent = CreateEvent(name);

        Assert.Equal(FormatWith(new Reference.CompactJsonFormatter(), logEvent), FormatWith(new PoShLogCompact(), logEvent));
    }

    [Theory]
    [MemberData(nameof(Events))]
    public void Rendered_MatchesSerilogFormattingCompact(string name)
    {
        var logEvent = CreateEvent(name);

        Assert.Equal(FormatWith(new Reference.RenderedCompactJsonFormatter(), logEvent), FormatWith(new PoShLogCompact(rendered: true), logEvent));
    }

    [Fact]
    public void GetCompactFormatter_ReturnsFormatter()
    {
        var results = Invoke("Get-CompactFormatter; Get-CompactFormatter -Rendered");

        Assert.False(Assert.IsType<PoShLogCompact>(results[0].BaseObject).Rendered);
        Assert.True(Assert.IsType<PoShLogCompact>(results[1].BaseObject).Rendered);
    }

    [Fact]
    public void FileSink_WithCompactFormatter_WritesOneClefObjectPerLine()
    {
        var path = Path.Combine(_tempDirectory, "clef.log").Replace("'", "''");
        Invoke($"New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkFile -Path '{path}' -Formatter (Get-CompactFormatter) | Start-Logger");
        Invoke("Write-InfoLog 'Service {Name} is {@State}' -PropertyValues 'EventLog', ([pscustomobject]@{ Status = 'Running' }); Write-ErrorLog 'broken'");
        Invoke("Close-Logger");

        var lines = File.ReadAllLines(path);
        Assert.Equal(2, lines.Length);

        using var first = JsonDocument.Parse(lines[0]);
        Assert.Equal("Service {Name} is {@State}", first.RootElement.GetProperty("@mt").GetString());
        Assert.Equal("EventLog", first.RootElement.GetProperty("Name").GetString());
        Assert.Equal("Running", first.RootElement.GetProperty("State").GetProperty("Status").GetString());
        Assert.False(first.RootElement.TryGetProperty("@l", out _));

        using var second = JsonDocument.Parse(lines[1]);
        Assert.Equal("Error", second.RootElement.GetProperty("@l").GetString());
    }

    [Fact]
    public void ConsoleSink_AcceptsRenderedCompactFormatter()
    {
        Invoke("New-Logger | Add-SinkConsole -Formatter (Get-CompactFormatter -Rendered) | Start-Logger; Write-InfoLog 'to console'; Close-Logger");
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(_tempDirectory))
        {
            Directory.Delete(_tempDirectory, recursive: true);
        }
    }
}
