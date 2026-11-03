using Serilog.Events;

namespace PoShLog.UnitTests;

/// <summary>
/// Covers Push-LogContextProperty (issue #34, ADR 0006).
/// </summary>
public class PushLogContextPropertyTests : PoShLogTestBase
{
    private readonly CollectingSink _sink = new();

    public PushLogContextPropertyTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        Shell.Runspace.SessionStateProxy.SetVariable("sink", _sink);
        Invoke("New-Logger | Set-MinimumLevel -Value Verbose | Add-EnrichFromLogContext | ForEach-Object { $_.WriteTo.Sink($sink) } | Start-Logger");
    }

    private LogEvent EventWithMessage(string text) =>
        _sink.Events.Single(e => e.MessageTemplate.Text == text);

    [Fact]
    public void ScriptBlock_AppliesPropertyInside_AndPopsItAfter()
    {
        Invoke("Push-LogContextProperty -Name RunId -Value 42 -ScriptBlock { Write-InfoLog 'inside' }; Write-InfoLog 'after'");

        Assert.Equal(42, ((ScalarValue)EventWithMessage("inside").Properties["RunId"]).Value);
        Assert.False(EventWithMessage("after").Properties.ContainsKey("RunId"));
    }

    [Fact]
    public void ScriptBlock_PopsPropertyEvenWhenItThrows()
    {
        // The caught throw still sets HadErrors on the runspace, so errors are allowed here.
        var results = Invoke("try { Push-LogContextProperty RunId 1 { throw 'boom' } } catch { 'caught' }; Write-InfoLog 'after'", allowErrors: true);

        Assert.Equal("caught", Assert.Single(results).BaseObject);
        Assert.False(EventWithMessage("after").Properties.ContainsKey("RunId"));
    }

    [Fact]
    public void ScriptBlock_OutputIsPassedThrough_AndRunsInChildScope()
    {
        var results = Invoke("$x = 'outer'; Push-LogContextProperty A 1 { $x = 'inner'; 'one'; 'two' }; $x");

        Assert.Equal(new object[] { "one", "two", "outer" }, results.Select(r => r.BaseObject));
    }

    [Fact]
    public void Bookmark_KeepsPropertyUntilDisposed_WithinTheSameScript()
    {
        // The LogContext is an AsyncLocal: it lasts for the rest of the script that pushed it, not across
        // separate pipeline invocations (ADR 0006).
        Invoke("$bookmark = Push-LogContextProperty Job nightly; function Step { Write-InfoLog 'second statement' }; Step; $bookmark.Dispose(); Write-InfoLog 'disposed'");

        Assert.Equal("nightly", ((ScalarValue)EventWithMessage("second statement").Properties["Job"]).Value);
        Assert.False(EventWithMessage("disposed").Properties.ContainsKey("Job"));
    }

    [Fact]
    public void NestedScopes_StackAndUnwind()
    {
        Invoke("Push-LogContextProperty A 1 { Push-LogContextProperty B 2 { Write-InfoLog 'both' }; Write-InfoLog 'only a' }");

        Assert.True(EventWithMessage("both").Properties.ContainsKey("A"));
        Assert.True(EventWithMessage("both").Properties.ContainsKey("B"));
        Assert.True(EventWithMessage("only a").Properties.ContainsKey("A"));
        Assert.False(EventWithMessage("only a").Properties.ContainsKey("B"));
    }

    [Fact]
    public void Property_HashtablePushesSeveralAtOnce()
    {
        Invoke("Push-LogContextProperty -Property @{ Job = 'nightly'; Step = 2 } -ScriptBlock { Write-InfoLog 'many' }");

        var properties = EventWithMessage("many").Properties;
        Assert.Equal("nightly", ((ScalarValue)properties["Job"]).Value);
        Assert.Equal(2, ((ScalarValue)properties["Step"]).Value);
    }

    [Fact]
    public void Destructure_LogsPSCustomObjectAsStructure()
    {
        Invoke("Push-LogContextProperty Item ([pscustomobject]@{ Id = 7 }) -Destructure { Write-InfoLog 'structured' }");

        var structure = Assert.IsType<StructureValue>(EventWithMessage("structured").Properties["Item"]);
        Assert.Equal("Id", Assert.Single(structure.Properties).Name);
    }

    [Fact]
    public void WithoutDestructure_WrappedScalarStaysScalar()
    {
        Invoke("$n = 1..3 | Measure-Object -Sum | Select-Object -ExpandProperty Sum; Push-LogContextProperty Total $n { Write-InfoLog 'sum' }");

        Assert.Equal(6.0, ((ScalarValue)EventWithMessage("sum").Properties["Total"]).Value);
    }

    [Fact]
    public void EmptyName_IsRejected()
    {
        Invoke("Push-LogContextProperty -Name '' -Value 1", allowErrors: true);

        Assert.NotNull(LastException);
    }
}
