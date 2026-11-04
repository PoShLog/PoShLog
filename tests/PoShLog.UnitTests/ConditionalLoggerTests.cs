using Serilog;
using Serilog.Sinks.SystemConsole.Themes;

namespace PoShLog.UnitTests;

public class ConditionalLoggerTests(PoShLogModuleFixture fixture) : PoShLogTestBase(fixture)
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "PoShLogIssues_" + Guid.NewGuid());

    private string Prepare()
    {
        Directory.CreateDirectory(directory);
        return directory.Replace("'", "''");
    }

    [Fact]
    public void ConditionalLogger_RoutesOnlyMatchingProperties_WithoutFilteringParent()
    {
        var path = Prepare();
        Invoke($$"""
            $child = New-Logger | Add-SinkFile -Path '{{path}}/selected.log' -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger -PassThru
            New-Logger | Add-SinkFile -Path '{{path}}/all.log' -OutputTemplate '{Message:lj}{NewLine}' |
                Add-SinkLogger -Logger $child -Filter 'Send = true' | Start-Logger
            Write-InfoLog 'selected {Send}' -PropertyValues $true
            Write-InfoLog 'excluded {Send}' -PropertyValues $false
            Write-InfoLog 'missing'
            Close-Logger
            $child.Dispose()
            """);
        Assert.Equal("selected true" + Environment.NewLine, File.ReadAllText(Path.Combine(directory, "selected.log")));
        Assert.Contains("excluded", File.ReadAllText(Path.Combine(directory, "all.log")));
        Assert.Contains("missing", File.ReadAllText(Path.Combine(directory, "all.log")));
    }

    [Fact]
    public void ConditionalLogger_InvalidExpressionFailsDuringConfiguration()
    {
        Invoke("$child = New-Logger | Start-Logger -PassThru; try { New-Logger | Add-SinkLogger -Logger $child -Filter 'Send = (' -ErrorAction Stop } finally { $child.Dispose() }", allowErrors: true);
        Assert.NotNull(LastException);
        Assert.Contains("Invalid Serilog filter expression.", LastException!.Message);
    }

    [Fact]
    public void ConditionalLogger_ExpressionTypesAreInternalAndHiddenFromPowerShell()
    {
        Invoke("$child = New-Logger | Start-Logger -PassThru; New-Logger | Add-SinkLogger -Logger $child -Filter 'Send = true' | Start-Logger; Close-Logger; $child.Dispose()");
        var core = typeof(PoShLog.Core.Formatting.CompactJsonFormatter).Assembly;
        Assert.DoesNotContain(core.GetExportedTypes(), t => t.Namespace?.StartsWith("Serilog") == true);
        var engine = core.GetType("Serilog.Expressions.SerilogExpression", throwOnError: true)!;
        Assert.False(engine.IsVisible);
        Assert.False(core.GetType("Serilog.LoggerSinkConfigurationExtensions", throwOnError: true)!.IsVisible);
        Assert.DoesNotContain(AppDomain.CurrentDomain.GetAssemblies(), a => a.GetName().Name == "Serilog.Expressions");
        Assert.DoesNotContain(Invoke("'Serilog.LoggerSinkConfigurationExtensions' -as [type]; 'Serilog.Expressions.SerilogExpression' -as [type]"),
            value => value is not null);
    }

    [Fact]
    public void ConditionalLogger_EvaluatesOnBackgroundThreads_AndRetainsCallerOwnership()
    {
        var path = Prepare();
        var result = Invoke($$"""
            $child = New-Logger | Add-SinkFile -Path '{{path}}/threads.log' -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger -PassThru
            New-Logger | Add-SinkLogger -Logger $child -Filter 'Accept = true' -RestrictedToMinimumLevel Warning | Start-Logger -PassThru
            """);
        using var logger = (Serilog.Core.Logger)Assert.Single(result).BaseObject;
        Parallel.For(0, 100, i =>
        {
            logger.Warning("accept {Accept}", true);
            logger.Warning("reject {Accept}", false);
            logger.Information("below minimum {Accept}", true);
        });
        logger.Dispose();
        Invoke("$child.Information('still owned by caller'); $child.Dispose()");
        var lines = File.ReadAllLines(Path.Combine(directory, "threads.log"));
        Assert.Equal(101, lines.Length);
        Assert.Equal(100, lines.Count(l => l == "accept true"));
        Assert.Equal("still owned by caller", lines[^1]);
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }
}
