using System.Collections.ObjectModel;
using System.Management.Automation;

namespace PoShLog.UnitTests;

/// <summary>
/// Ensures every test class that uses <see cref="PoShLogModuleFixture"/> shares the same
/// collection and never runs in parallel with another, since PoShLog relies on the static
/// [Serilog.Log]::Logger property being manipulated one test at a time.
/// </summary>
[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class PoShLogCollection : ICollectionFixture<PoShLogModuleFixture>
{
    public const string Name = "PoShLog module collection";
}

/// <summary>
/// Common base class for cmdlet tests. Provides a fresh <see cref="PowerShell"/> instance per
/// test (with the PoShLog functions and types already loaded) and resets global logger state
/// after each test so tests do not leak into one another.
/// </summary>
[Collection(PoShLogCollection.Name)]
public abstract class PoShLogTestBase : IDisposable
{
    protected PoShLogModuleFixture Fixture { get; }
    protected PowerShell Shell { get; }

    /// <summary>
    /// The exception thrown by the last <see cref="Invoke"/> call, when <c>allowErrors: true</c>
    /// was passed and the script raised a terminating error (e.g. a missing mandatory parameter
    /// or a parameter binding validation failure). Null if no exception occurred.
    /// </summary>
    protected Exception? LastException { get; private set; }

    protected PoShLogTestBase(PoShLogModuleFixture fixture)
    {
        Fixture = fixture;
        Shell = fixture.CreateShell();
    }

    /// <summary>
    /// Invokes the given script and returns the pipeline output. Throws if the script
    /// produced any non-terminating errors, unless <paramref name="allowErrors"/> is true.
    /// Terminating errors (e.g. missing mandatory parameters) are captured into
    /// <see cref="LastException"/> when <paramref name="allowErrors"/> is true.
    /// </summary>
    protected Collection<PSObject> Invoke(string script, bool allowErrors = false)
    {
        Shell.Commands.Clear();
        Shell.Streams.ClearStreams();
        Shell.AddScript(script);
        LastException = null;

        Collection<PSObject> results;
        try
        {
            results = Shell.Invoke();
        }
        catch (Exception ex) when (allowErrors)
        {
            LastException = ex;
            return new Collection<PSObject>();
        }

        if (!allowErrors && Shell.HadErrors)
        {
            var errors = string.Join(Environment.NewLine, Shell.Streams.Error.Select(e => e.ToString()));
            throw new InvalidOperationException($"Script produced errors:{Environment.NewLine}{script}{Environment.NewLine}{errors}");
        }

        return results;
    }

    public void Dispose()
    {
        Dispose(true);
        GC.SuppressFinalize(this);
    }

    protected virtual void Dispose(bool disposing)
    {
        if (!disposing)
        {
            return;
        }

        try
        {
            Shell.Commands.Clear();
            Shell.Streams.ClearStreams();
            Shell.AddScript("if ([Serilog.Log]::Logger) { [Serilog.Log]::CloseAndFlush() }");
            Shell.Invoke();
        }
        catch
        {
            // best effort cleanup, ignore failures resetting global logger state between tests
        }
        finally
        {
            var runspace = Shell.Runspace;
            Shell.Dispose();
            runspace?.Dispose();
        }
    }
}
