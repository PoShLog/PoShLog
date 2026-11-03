using System.Management.Automation;
using PoShLog.Core.Exceptions;
using Serilog.Events;

namespace PoShLog.UnitTests;

public class ErrorLoggingRegressionTests : PoShLogTestBase
{
    private readonly CollectingSink _sink = new();

    public ErrorLoggingRegressionTests(PoShLogModuleFixture fixture) : base(fixture)
    {
        Shell.Runspace.SessionStateProxy.SetVariable("sink", _sink);
        Invoke("New-Logger | Set-MinimumLevel -Value Verbose | Add-EnrichWithErrorRecord -DestructureObjects | ForEach-Object { $_.WriteTo.Sink($sink) } | Start-Logger");
    }

    public static IEnumerable<object[]> WriteCommands =>
        new[] { "Verbose", "Debug", "Info", "Information", "Warning", "Error", "Fatal" }
            .SelectMany(level => new[] { false, true }.Select(passThru => new object[] { $"Write-{level}Log", passThru }));

    [Theory]
    [MemberData(nameof(WriteCommands))]
    public void OmittedMessage_EmitsOneEvent_AndHonorsPassThru(string command, bool passThru)
    {
        Invoke("try { throw 'regression failure' } catch { $record = $_ }");
        var results = Invoke($"{command} -ErrorRecord $record {(passThru ? "-PassThru" : "")}");
        var logged = Assert.Single(_sink.Events);
        Assert.Equal("", logged.MessageTemplate.Text);
        Assert.Equal("regression failure", logged.Exception!.InnerException!.Message);
        if (passThru) Assert.Single(results);
        else Assert.Empty(results);
    }

    [Theory]
    [MemberData(nameof(WriteCommands))]
    public void ConstructedRecord_EmitsWithOptionalInvocationMetadata(string command, bool passThru)
    {
        var record = new ErrorRecord(new InvalidOperationException("constructed failure"), "Constructed", ErrorCategory.InvalidOperation, null);
        Assert.Null(record.InvocationInfo);
        Shell.Runspace.SessionStateProxy.SetVariable("record", record);
        var results = Invoke($"{command} 'explicit message' -ErrorRecord $record {(passThru ? "-PassThru" : "")}");
        var logged = Assert.Single(_sink.Events);
        Assert.Null(Assert.IsType<WrapperException>(logged.Exception).ErrorRecordWrapper.InvocationInfoWrapper);
        Assert.Equal("constructed failure", logged.Exception!.InnerException!.Message);
        Assert.Equal("explicit message", logged.RenderMessage());
        if (passThru) Assert.Single(results);
        else Assert.Empty(results);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public void InvocationMetadata_OmitsArgumentsAndSourceText(bool destructure)
    {
        Invoke($"New-Logger | Add-EnrichWithErrorRecord {(destructure ? "-DestructureObjects" : "")} | ForEach-Object {{ $_.WriteTo.Sink($sink) }} | Start-Logger");
        // Synthetic markers only; assertions target invocation metadata, not arbitrary exception text.
        var script = Path.Combine(Path.GetTempPath(), $"poshlog-metadata-{Guid.NewGuid():N}.ps1");
        File.WriteAllText(script, """
            function Invoke-Failing { [CmdletBinding()] param([string]$Value) throw 'constant failure' }
            try { Invoke-Failing -Value 'synthetic-bound-marker' } catch {
                # InvocationInfo collections can also be populated by an error producer.
                $_.InvocationInfo.BoundParameters['Value'] = 'synthetic-bound-marker'
                $_.InvocationInfo.UnboundArguments.Add('synthetic-unbound-marker')
                Write-ErrorLog 'failed' -ErrorRecord $_
            }
            try { Get-Item -LiteralPath 'synthetic-bound-marker' -ErrorAction Stop } catch {
                Write-ErrorLog 'failed' -ErrorRecord $_
            }
            """);
        try { Invoke($"& '{script.Replace("'", "''")}'"); }
        finally { File.Delete(script); }
        Assert.Equal(2, _sink.Events.Count);
        Assert.Equal("Get-Item", Assert.IsType<WrapperException>(_sink.Events[1].Exception).ErrorRecordWrapper.InvocationInfoWrapper.MyCommand);
        foreach (var logged in _sink.Events)
        {
            var wrapper = Assert.IsType<WrapperException>(logged.Exception).ErrorRecordWrapper.InvocationInfoWrapper;
            Assert.NotNull(wrapper);
            Assert.Equal(script, wrapper.ScriptName);
            Assert.True(wrapper.ScriptLineNumber > 0);
            var metadata = logged.Properties["InvocationInfo"].ToString();
            Assert.DoesNotContain("synthetic-bound-marker", metadata);
            Assert.DoesNotContain("synthetic-unbound-marker", metadata);
            Assert.DoesNotContain("synthetic-", wrapper.ToString());
            foreach (var property in new[] { "BoundParameters", "UnboundArguments", "Line", "PositionMessage", "DisplayScriptPosition" })
                Assert.Null(wrapper.GetType().GetProperty(property));
        }
    }
}
