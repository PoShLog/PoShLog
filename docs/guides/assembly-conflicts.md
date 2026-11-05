# Assembly conflicts

A PowerShell session is one process: modules share the DLLs loaded in it. Within a shared load context, a DLL name
can have only one loaded version, so the version loaded first matters. Private load contexts can isolate a module's
dependencies, but assemblies used to pass logging objects between modules must stay shared.

PoShLog v3 repository builds target .NET 10 (`net10.0`) for PowerShell 7.6+ and .NET Framework 4.7.2 (`net472`)
for Windows PowerShell 5.1.

## PowerShell 7.6+

Core ships only three separate dependency DLLs: **Serilog**, **Serilog.Sinks.File** and **Serilog.Sinks.Console**.
The `System.*` libraries come from .NET 10 itself and are shared by everything. .NET can satisfy a request for an
older assembly with an already loaded newer version; this lets the published 1.0.x extensions built against older Serilog
work with v3.

The shared Serilog conflict to watch for is another module loading an **older Serilog before PoShLog**. Start a
fresh session and import PoShLog first.

| Feature | How it avoids conflicts |
|---|---|
| MSSqlServer sink | Keeps Microsoft.Data.SqlClient and its private dependencies in a private load context, separate from other SQL modules. Serilog stays shared. |
| `Add-SinkLogger -Filter` | Serilog.Expressions is built into PoShLog.Core.dll with its implementation hidden. There is no separate Expressions DLL or load context to clash with other modules. |

## Windows PowerShell 5.1

> [!NOTE]
> Core phase 1 is implemented in repository builds. This support is unreleased.

.NET Framework has no private load context. Serilog 4 needs backport libraries that other modules can also load:

- System.Diagnostics.DiagnosticSource and System.Threading.Channels;
- through them, System.Memory, System.Buffers, System.Runtime.CompilerServices.Unsafe, System.Numerics.Vectors
  and System.Threading.Tasks.Extensions.
- JSON configuration also ships pinned System.Text.Json, System.Text.Encodings.Web, System.IO.Pipelines and
  Microsoft.Bcl.AsyncInterfaces. The latter is loaded through ordinary Framework binding, outside the System.* resolver whitelist.

The VS Code PowerShell extension, Az, Microsoft.Graph and PnP can bring their own versions of these libraries.
PoShLog's Desktop build handles the shared dependencies as follows:

- Core owns pinned versions of its shared libraries. Desktop extension ports must use those shared copies.
- A resolver handles only Core-owned shared assemblies. It serves Core's copy for a request for the same or an
  older version, never a newer one. Loading PoShLog first can therefore help other modules too.
- An import guard stops with a clear message if PoShLog 2.x or a Serilog older than Core's is already loaded. If
  another module loaded an older backport library first, the import fails with an assembly error instead.

Import PoShLog early, ideally at the top of your script. If the import stops in the VS Code integrated console,
run the script in a fresh `powershell.exe` session. Scheduled tasks and plain scripts are rarely affected because
they usually start a fresh process with fewer modules loaded. **Never add binding redirects to
`powershell.exe.config`.**

The first Desktop build does not include `Add-SinkLogger -Filter` or expression-based JSON filters: they fail with a
clear "not supported on Windows PowerShell" error and load nothing extra into the session. The MSSqlServer sink stays
PowerShell 7.6+ only. Both are planned for a later build ([ADR 0031](../decisions/0031-windows-powershell-desktop-support.md),
phase 2).

## Troubleshooting

An assembly conflict often appears as `Could not load file or assembly ...` or a `FileLoadException` naming an
assembly version. Check the full message: a missing DLL can also mean an incomplete installation.

To see the Serilog assemblies already loaded, including their versions:

```powershell
[AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -like 'Serilog*' } | ForEach-Object { $_.GetName().FullName }
```

Replace `'Serilog*'` with the name in the error (for example, `'System.Memory'`) to check a backport library.
Restart the process before trying a different import order; removing a module does not unload its DLLs.

If a fresh session still fails, use the [bug report form](https://github.com/PoShLog/PoShLog/issues/new?template=bug_report.yml).
Include the full error, the assembly list above, `Get-Module` output, `$PSVersionTable`, and a minimal script showing
the import order. Remove credentials and other sensitive values before posting.
