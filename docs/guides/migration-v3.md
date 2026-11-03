# Migration Guide: PoShLog v2.x → v3.0

## Overview

PoShLog v3.0 is a major rewrite — the module is now a **compiled C# binary module** targeting **.NET 8.0** and **PowerShell 7.4+**.

### Key Changes

| Area | v2.x | v3.0 |
|---|---|---|
| Module type | Script module (.psm1) | Binary module (.dll) |
| PowerShell | 5.1+ (Desktop & Core) | **7.4+ only** |
| Serilog | 2.10.0 | **4.4.0** |
| Serilog.Sinks.Console | 3.1.1 | **6.1.1** |
| Serilog.Sinks.File | 4.1.0 | **7.0.0** |
| .NET Target | netstandard2.0 | **net8.0** |

### What Stays the Same

- All cmdlet names (New-Logger, Start-Logger, Write-InfoLog, etc.)
- All parameter names and pipeline behavior
- Module GUID: `6eabf344-4f00-4cc0-95d4-d3bef503e165`

---

## Breaking Changes

### 1. PowerShell 5.1 is no longer supported

PoShLog v3.0 requires PowerShell 7.4 or later. If you need PS 5.1 support, stay on v2.x.

### 2. Extension modules remain compatible

v2 extension modules work with v3: the shared `Serilog.LoggerConfiguration` pipeline and default assembly load context remain the public contract (ADR 0003). PoShLog.Sinks.Seq 1.0.0 was verified delivering events to a local listener with v3.

Seq, EventLog, Http and Enrichers have refreshed 2.0.0 builds under `extensions/`; which version works with which PoShLog is on the [compatibility page](../compatibility.md). Published versions and third-party extensions are tested in CI against freshly built Core. EventLog requires Windows. For Elasticsearch on v3, use the new PoShLog.Sinks.Elastic ([Add-SinkElasticsearch](../sinks/Add-SinkElasticsearch.md)); the third-party Elasticsearch module is Windows PowerShell only and ships its own Serilog.dll, so it stays with PoShLog 2.x on Windows PowerShell 5.1.

### 3. Internal helpers

| Cmdlet | Reason |
|---|---|
| `Add-PackageTypes` | Never exported; binary module loads dependencies at import |
| `Test-PsCore` | Never exported; the manifest requires PowerShell 7.4+ |

---

## Upgrading

v2 and v3 install side by side; you do not need to uninstall v2 first.

```powershell
# Install the v3 preview next to the version you have
Install-Module PoShLog -AllowPrerelease

# Verify (in a new session)
Import-Module PoShLog
Get-Module PoShLog | Select-Object Version, ModuleType
# Version 3.0.0, ModuleType Binary
```

Scripts that must stay on v2 pin it with `#Requires -Modules @{ ModuleName = 'PoShLog'; RequiredVersion = '2.2.0' }`.
To go back, uninstall only the preview. The exact commands, how extensions install during the preview, and how this was
tested are on the [compatibility page](../compatibility.md).

---

## Advanced: other Serilog sinks without a wrapper module

PoShLog 3 hands you a plain `Serilog.LoggerConfiguration`, so a Serilog sink package can be configured directly from
PowerShell. This is an advanced route: prefer a PoShLog extension when one exists, because extensions are built and
tested against Core ([sinks page](../sinks/README.md)).

Constraints:

- **Serilog 4, no newer than Core's.** The sink must target Serilog 4.x at or below the version PoShLog ships
  (4.4.0). Core loads Serilog, Serilog.Sinks.File and Serilog.Sinks.Console and nothing else
  ([ADR 0011](../decisions/0011-core-does-not-load-assemblies-extensions-ship.md)).
- **A .NET 8 compatible build** (`net8.0`, an older `net*` or `netstandard2.x` folder of the package).
- **You load every dependency yourself**, in dependency order, before the sink assembly. One process holds one version
  of an assembly: if another module already loaded an older copy, the first one loaded wins and the sink may fail.
- **Not covered by PoShLog's tests.** Pin the package version you tested.

```powershell
# The sink's DLLs (and their dependencies) are unpacked from its NuGet package into .\lib
Get-ChildItem .\lib -Filter *.dll | ForEach-Object { Add-Type -Path $_.FullName }

$config = New-Logger
# Serilog sinks are extension methods on LoggerSinkConfiguration: call the static class the package defines.
[Serilog.ExampleSinkLoggerConfigurationExtensions]::ExampleSink($config.WriteTo, 'https://logs.example.com') | Out-Null
$config | Add-SinkConsole | Start-Logger
```

Wrap it in a small function with a `[Serilog.LoggerConfiguration]` pipeline parameter that returns the configuration,
and it composes like any `Add-Sink*` cmdlet. [Creating a sink](creating-sink.md) shows the full pattern.

---

## For Extension Module Authors

If you maintain a PoShLog extension module and want to support v3.0:

1. **Reference Serilog 4.x**, no newer than the version Core ships (4.4.0).
2. **Target net8.0** (or netstandard2.0 if you need broader compat — Serilog 4.x supports both).
3. **Choose the PoShLog minimum by GUID:**
   - A release that serves v2 and v3 keeps PoShLog `2.0.0` and the Serilog version v2 ships; the 1.0.x extensions
     work this way ([ADR 0003](../decisions/0003-keep-the-v2-extension-contract.md)).
   - A release that needs v3 (Serilog 4, PowerShell 7.4) requires PoShLog 3. While v3 is a prerelease, declare
     `2.99.0` so package managers can resolve the preview
     ([ADR 0017](../decisions/0017-extensions-require-poshlog-2-99-while-core-is-prerelease.md)):
     ```powershell
     RequiredModules = @(@{ ModuleName = 'PoShLog'; GUID = '6eabf344-4f00-4cc0-95d4-d3bef503e165'; ModuleVersion = '2.99.0' })
     ```
4. **Test with PowerShell 7.4+**
5. **Consider converting to a binary module** for better performance and type safety

### Common API changes in Serilog 4.x

- `ILogEventEnricher` interface unchanged
- `ILogEventSink.Emit(LogEvent)` unchanged
- `WriteTo` extension methods — mostly compatible, check your specific sink's changelog
- `LoggerConfiguration` fluent API — unchanged
- `Serilog.Formatting.Json.JsonFormatter` remains available in Serilog 4.

---

## FAQ

**Q: Can I use v2.x extension modules with v3.0?**
A: Yes. v3 preserves the v2 extension contract. PoShLog.Sinks.Seq 1.0.0 was verified shipping events on v3; CI tests pinned published extensions. The third-party Elasticsearch module is Windows PowerShell only and stays on PoShLog 2.x; on v3 use PoShLog.Sinks.Elastic.

**Q: Will official extension modules be updated?**
A: Yes. PoShLog.Enrichers, PoShLog.Sinks.Seq, PoShLog.Sinks.EventLog and PoShLog.Sinks.Http have 2.0.0 builds for v3; see the [compatibility page](../compatibility.md).

**Q: My script uses Write-InfoLog, do I need to change anything?**
A: No — all cmdlet names and parameters are unchanged. Just update the module version.

**Q: I need PowerShell 5.1 support, what do I do?**
A: Stay on PoShLog v2.x. It will continue to work but won't receive new features.
