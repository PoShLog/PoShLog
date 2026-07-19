using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace PoShLog.UnitTests;

/// <summary>
/// Loads the compiled PoShLog.Core.dll binary module so tests exercise the real compiled
/// PSCmdlet/Cmdlet implementations inside an in-process PowerShell runspace.
/// </summary>
public sealed class PoShLogModuleFixture
{
    public string ModulePath { get; }

    public PoShLogModuleFixture()
    {
        ModulePath = Path.Combine(AppContext.BaseDirectory, "PoShLog.Core.dll");

        if (!File.Exists(ModulePath))
        {
            throw new InvalidOperationException($"Could not locate compiled module at '{ModulePath}'.");
        }
    }

    /// <summary>
    /// Creates a fresh PowerShell instance with the compiled PoShLog module already imported.
    /// </summary>
    public PowerShell CreateShell()
    {
        var initialSessionState = InitialSessionState.CreateDefault();
        initialSessionState.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
        var runspace = RunspaceFactory.CreateRunspace(initialSessionState);
        runspace.Open();

        var shell = PowerShell.Create(runspace);
        shell.AddCommand("Import-Module")
            .AddParameter("Name", ModulePath)
            .AddParameter("ErrorAction", "Stop");
        shell.Invoke();

        if (shell.HadErrors)
        {
            var errors = string.Join(Environment.NewLine, shell.Streams.Error.Select(e => e.ToString()));
            shell.Dispose();
            throw new InvalidOperationException($"Failed to import compiled PoShLog module for testing:{Environment.NewLine}{errors}");
        }

        shell.Commands.Clear();
        shell.Streams.ClearStreams();
        return shell;
    }
}
