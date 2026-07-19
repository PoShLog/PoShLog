using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;

namespace PoShLog.UnitTests;

/// <summary>
/// Loads the PoShLog dotnet assemblies and dot-sources every function script under
/// src/functions so tests can exercise the real cmdlet implementations inside an
/// in-process PowerShell runspace, without depending on a fully packaged module.
/// </summary>
public sealed class PoShLogModuleFixture
{
    private static readonly string[] RequiredAssemblyNames =
    {
        "Serilog.dll",
        "Serilog.Sinks.Console.dll",
        "Serilog.Sinks.File.dll",
        "PoShLog.Core.dll",
    };

    public string FunctionsDirectory { get; }
    public string RepositoryRoot { get; }

    public PoShLogModuleFixture()
    {
        RepositoryRoot = ResolveRepositoryRoot();
        FunctionsDirectory = Path.Combine(RepositoryRoot, "src", "functions");

        if (!Directory.Exists(FunctionsDirectory))
        {
            throw new InvalidOperationException($"Could not locate functions directory at '{FunctionsDirectory}'.");
        }
    }

    /// <summary>
    /// Creates a fresh PowerShell instance with the PoShLog types and functions already loaded.
    /// </summary>
    public PowerShell CreateShell()
    {
        var initialSessionState = InitialSessionState.CreateDefault();
        initialSessionState.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;
        var runspace = RunspaceFactory.CreateRunspace(initialSessionState);
        runspace.Open();

        var shell = PowerShell.Create(runspace);
        shell.AddScript(BuildImportScript());
        shell.Invoke();

        if (shell.HadErrors)
        {
            var errors = string.Join(Environment.NewLine, shell.Streams.Error.Select(e => e.ToString()));
            shell.Dispose();
            throw new InvalidOperationException($"Failed to import PoShLog functions for testing:{Environment.NewLine}{errors}");
        }

        shell.Commands.Clear();
        shell.Streams.ClearStreams();
        return shell;
    }

    private string BuildImportScript()
    {
        var baseDirectory = AppContext.BaseDirectory;
        var sb = new StringBuilder();
        sb.AppendLine("$ErrorActionPreference = 'Stop'");
        sb.AppendLine("$Global:loggerNotInitWarned = $false");

        foreach (var assemblyName in RequiredAssemblyNames)
        {
            var fullPath = Path.Combine(baseDirectory, assemblyName);
            sb.AppendLine($"Add-Type -Path '{EscapeSingleQuotes(fullPath)}'");
        }

        sb.AppendLine("$global:TextFormatter = [Serilog.Formatting.Display.MessageTemplateTextFormatter]::new('{Message:lj}')");

        foreach (var file in Directory.GetFiles(FunctionsDirectory, "*.ps1", SearchOption.AllDirectories))
        {
            sb.AppendLine($". '{EscapeSingleQuotes(file)}'");
        }

        return sb.ToString();
    }

    private static string EscapeSingleQuotes(string value) => value.Replace("'", "''");

    private static string ResolveRepositoryRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "src", "functions")))
        {
            dir = dir.Parent;
        }

        return dir?.FullName
            ?? throw new InvalidOperationException("Could not locate repository root containing 'src/functions'.");
    }
}
