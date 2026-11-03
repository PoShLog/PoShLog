using System.Diagnostics;
using Serilog.Events;

namespace PoShLog.UnitTests;

/// <summary>
/// Covers the PSObject destructuring policy Start-Logger registers (issue #46, ADR 0005).
/// </summary>
public class PSObjectDestructuringTests : PoShLogTestBase
{
    private readonly CollectingSink _sink = new();

    public PSObjectDestructuringTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        Shell.Runspace.SessionStateProxy.SetVariable("sink", _sink);
        Invoke("New-Logger | Set-MinimumLevel -Value Verbose | ForEach-Object { $_.WriteTo.Sink($sink) } | Start-Logger");
    }

    private LogEventPropertyValue LogAndCapture(string setup, string propertyName = "Value")
    {
        Invoke(setup + $"; Write-InfoLog '{{@{propertyName}}}' -PropertyValues $value");
        var logEvent = Assert.Single(_sink.Events);
        return logEvent.Properties[propertyName];
    }

    [Fact]
    public void CalculatedProperty_FromSelectObject_IsTheScalarNotTheAdapter()
    {
        // The repro from issue #46: a Select-Object calculated property is a PSObject wrapping a string.
        var value = LogAndCapture("$svc = [pscustomobject]@{ Name = 'EventLog' } | Select-Object Name, @{ l = 'canControl'; e = { 'canControl' } }; $value = $svc.canControl");

        var scalar = Assert.IsType<ScalarValue>(value);
        Assert.Equal("canControl", scalar.Value);
    }

    [Fact]
    public void PSCustomObject_BecomesStructureOfItsProperties()
    {
        var value = LogAndCapture("$value = [pscustomobject]@{ Name = 'a'; Count = 3 } | Add-Member -MemberType ScriptProperty -Name Double -Value { $this.Count * 2 } -PassThru | Add-Member -MemberType ScriptMethod -Name Go -Value { 1 } -PassThru");

        var structure = Assert.IsType<StructureValue>(value);
        Assert.Null(structure.TypeTag);
        Assert.Equal(new[] { "Name", "Count", "Double" }, structure.Properties.Select(p => p.Name));
        Assert.Equal(6, ((ScalarValue)structure.Properties.Single(p => p.Name == "Double").Value).Value);
    }

    [Fact]
    public void PSCustomObject_PropertyThatThrows_IsSkipped()
    {
        var value = LogAndCapture("$value = [pscustomobject]@{ Name = 'a' } | Add-Member -MemberType ScriptProperty -Name Broken -Value { throw 'no' } -PassThru");

        var structure = Assert.IsType<StructureValue>(value);
        Assert.Equal(new[] { "Name" }, structure.Properties.Select(p => p.Name));
    }

    [Fact]
    public void Cycle_IsCutWithMarker_AndDoesNotHang()
    {
        var stopwatch = Stopwatch.StartNew();
        var value = LogAndCapture("$a = [pscustomobject]@{ Name = 'a' }; $b = [pscustomobject]@{ Name = 'b'; Peer = $a }; $a | Add-Member Peer $b; $a | Add-Member Self $a; $value = $a");
        stopwatch.Stop();

        var a = Assert.IsType<StructureValue>(value);
        var b = Assert.IsType<StructureValue>(a.Properties.Single(p => p.Name == "Peer").Value);
        Assert.Equal("[Circular]", ((ScalarValue)b.Properties.Single(p => p.Name == "Peer").Value).Value);
        Assert.Equal("[Circular]", ((ScalarValue)a.Properties.Single(p => p.Name == "Self").Value).Value);
        Assert.True(stopwatch.Elapsed < TimeSpan.FromSeconds(10), $"Destructuring took {stopwatch.Elapsed}.");
    }

    [Fact]
    public void SameObjectTwiceSideBySide_IsNotACycle()
    {
        var value = LogAndCapture("$leaf = [pscustomobject]@{ N = 1 }; $value = [pscustomobject]@{ Left = $leaf; Right = $leaf }");

        var structure = Assert.IsType<StructureValue>(value);
        Assert.All(structure.Properties, p => Assert.IsType<StructureValue>(p.Value));
    }

    [Fact]
    public void DeepNesting_IsBoundedBySerilogMaximumDepth()
    {
        var value = LogAndCapture("$value = [pscustomobject]@{ Level = 0 }; $node = $value; 1..50 | ForEach-Object { $next = [pscustomobject]@{ Level = $_ }; $node | Add-Member Child $next; $node = $next }");

        var depth = 0;
        var current = value as StructureValue;
        while (current?.Properties.FirstOrDefault(p => p.Name == "Child")?.Value is StructureValue child)
        {
            depth++;
            current = child;
        }

        Assert.InRange(depth, 1, 10);
    }

    [Fact]
    public void Hashtable_BecomesDictionary_WithNestedObjects()
    {
        var value = LogAndCapture("$value = [ordered]@{ Latitude = 25; Inner = [pscustomobject]@{ B = 1 } }");

        var dictionary = Assert.IsType<DictionaryValue>(value);
        Assert.Equal(new object[] { "Latitude", "Inner" }, dictionary.Elements.Keys.Select(k => k.Value));
        Assert.IsType<StructureValue>(dictionary.Elements.Values.Last());
    }

    [Fact]
    public void Hashtable_ThatContainsItself_IsCut()
    {
        var value = LogAndCapture("$value = @{ Name = 'h' }; $value.Self = $value");

        var dictionary = Assert.IsType<DictionaryValue>(value);
        var self = dictionary.Elements.Single(e => (string)e.Key.Value! == "Self").Value;
        Assert.Equal("[Circular]", ((ScalarValue)self).Value);
    }

    [Fact]
    public void NonDestructuredPSCustomObject_StaysItsStringForm()
    {
        Invoke("Write-InfoLog '{Value}' -PropertyValues ([pscustomobject]@{ B = 1 })");

        var scalar = Assert.IsType<ScalarValue>(Assert.Single(_sink.Events).Properties["Value"]);
        Assert.Equal("@{B=1}", scalar.Value?.ToString());
    }

    [Fact]
    public void PassThru_RendersTheDestructuredObject()
    {
        var results = Invoke("Write-InfoLog 'Got {@Value}' -PropertyValues ([pscustomobject]@{ B = 1 }) -PassThru");

        Assert.Equal("Got {\"B\":1}", Assert.Single(results).BaseObject);
    }
}
