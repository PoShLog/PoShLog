# Creating a sink

In PoShLog we use sinks to log messages into particular places. This page explains how to create your own sink for the current C# binary module architecture.

## Project structure

The core module (`src/dotnet/PoShLog.Core.csproj`) targets net472 and net10.0. Shared code must compile on both.
A first-party sink is added as a new `PSCmdlet`/`Cmdlet` class under `src/dotnet/Cmdlets/Sinks/`, following the existing sink cmdlets.

* `src/dotnet/Cmdlets/Sinks/AddSinkConsoleCommand.cs`
* `src/dotnet/Cmdlets/Sinks/AddSinkFileCommand.cs`
* `src/dotnet/Cmdlets/Sinks/AddSinkPowerShellCommand.cs`

A third-party/extension sink module (e.g. `PoShLog.Sinks.Notepad`) is typically its own separate PowerShell (script) module or its own small binary module that depends on the relevant Serilog sink NuGet package and on `PoShLog.Core.dll` for shared types like `LoggerConfiguration`.

## How it works

Let's say we want to add support for `Serilog.Sinks.Notepad`.

### How it's done in C#

Reference the [`Serilog.Sinks.Notepad`](https://www.nuget.org/packages/Serilog.Sinks.Notepad/) NuGet package in your project file, then wire it up like any other Serilog sink:

```cs
Log.Logger = new LoggerConfiguration()
    .WriteTo.Notepad()
    .CreateLogger();
Log.Information("Hi");
Log.CloseAndFlush();
```

### How it's done as a PoShLog cmdlet

Add a new `Cmdlet`/`PSCmdlet` class (e.g. `AddSinkNotepadCommand`) that mirrors the existing sink cmdlets:

```csharp
using System.Management.Automation;
using Serilog;

namespace PoShLog.Core.Cmdlets.Sinks
{
    [Cmdlet(VerbsCommon.Add, "SinkNotepad")]
    [OutputType(typeof(LoggerConfiguration))]
    public class AddSinkNotepadCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public LoggerConfiguration LoggerConfig { get; set; }

        [Parameter(Mandatory = false)]
        public string OutputTemplate { get; set; }

        protected override void ProcessRecord()
        {
            LoggerConfig.WriteTo.Notepad(outputTemplate: OutputTemplate ?? "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}");

            WriteObject(LoggerConfig);
        }
    }
}
```

Prefer **named arguments** when calling Serilog's fluent sink extension methods (as the built-in sinks do) — this avoids depending on the exact positional overload signature of a given Serilog sink package version.

When a sink method has multiple overloads, expose separate PowerShell [parameter sets](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_parameter_sets) on the cmdlet, mirroring the existing `Add-SinkFile` cmdlet, which has both a default text-formatting parameter set and a `-Formatter` parameter set.

## Testing your sink

```ps1
Import-Module ./src/PoShLog.psd1

New-Logger |
    Add-SinkNotepad |
    Add-SinkConsole |
    Start-Logger

Write-InfoLog 'Test'

Close-Logger
```

## Publishing

Add xUnit tests for the new cmdlet under `tests/PoShLog.UnitTests/`, and (for end-to-end coverage) Pester tests under `tests/`. Once the build and tests pass, follow the module's existing [release process](../../.github/workflows/release.yml) to publish, or publish the sink as a standalone extension module to the PowerShell Gallery with `Publish-Module`.
