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

Seq, EventLog, Http and Enrichers have refreshed 2.0.0 builds under `extensions/`. Published versions and third-party extensions are tested in CI against freshly built Core. EventLog requires Windows. The third-party Elasticsearch module is Windows PowerShell only and ships its own Serilog.dll; use it with PoShLog 2.x on Windows PowerShell 5.1.

### 3. Internal helpers

| Cmdlet | Reason |
|---|---|
| `Add-PackageTypes` | Never exported; binary module loads dependencies at import |
| `Test-PsCore` | Never exported; the manifest requires PowerShell 7.4+ |

---

## Upgrading

```powershell
# Remove old version
Remove-Module PoShLog -Force -ErrorAction SilentlyContinue
Uninstall-Module PoShLog -AllVersions

# Install v3.0
Install-Module PoShLog -AllowPrerelease

# Verify
Import-Module PoShLog
Get-Module PoShLog | Select-Object Version, ModuleType
# Should show: Version 3.0.0, ModuleType: Binary
```

---

## Using Any Serilog Sink Without a Wrapper Module

With v3.0 you no longer need a dedicated PoShLog extension module for every sink. You can use **any Serilog sink NuGet package** directly:

### Option 1: Load the DLL manually

```powershell
# Download the sink package (one-time)
# e.g., from NuGet: https://www.nuget.org/packages/Serilog.Sinks.Datadog.Logs

# Load the assembly
Add-Type -Path "C:\path\to\Serilog.Sinks.Datadog.Logs.dll"

# Use the Serilog extension method directly
$logger = New-Logger
$config = $logger.WriteTo
[Serilog.DatadogLogsExtensions]::DatadogLogs($config, "your-api-key")
$logger | Start-Logger
```

### Option 2: Install via NuGet and load

```powershell
# Install NuGet package to a local folder
dotnet add package Serilog.Sinks.Datadog.Logs --package-directory .\packages

# Find and load the DLL
$dll = Get-ChildItem .\packages -Filter "Serilog.Sinks.Datadog.Logs.dll" -Recurse | Select-Object -First 1
Add-Type -Path $dll.FullName

# Use it
$logger = New-Logger
[Serilog.DatadogLogsExtensions]::DatadogLogs($logger.WriteTo, "your-api-key")
$logger | Start-Logger
```

### Option 3: Create a simple helper function

```powershell
function Add-SinkDatadog {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Serilog.LoggerConfiguration]$LoggerConfig,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [string]$Source = "powershell",
        [string]$Service = "my-app"
    )
    process {
        # Assumes Serilog.Sinks.Datadog.Logs.dll is loaded
        [Serilog.DatadogLogsExtensions]::DatadogLogs(
            $LoggerConfig.WriteTo, $ApiKey, $Source, $Service
        )
        $LoggerConfig
    }
}

# Usage:
New-Logger | Add-SinkDatadog -ApiKey "xxx" | Add-SinkConsole | Start-Logger
```

---

## For Extension Module Authors

If you maintain a PoShLog extension module and want to support v3.0:

1. **Update Serilog dependency** to 4.4.0+
2. **Target net8.0** (or netstandard2.0 if you need broader compat — Serilog 4.x supports both)
3. **Keep your module manifest minimum** at PoShLog 2.0.0 by GUID (one release can serve both lines):
   ```powershell
   RequiredModules = @(@{ ModuleName = 'PoShLog'; GUID = '6eabf344-4f00-4cc0-95d4-d3bef503e165'; ModuleVersion = '2.0.0' })
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
A: Yes. v3 preserves the v2 extension contract. PoShLog.Sinks.Seq 1.0.0 was verified shipping events on v3; CI tests pinned published extensions. Elasticsearch is Windows PowerShell only and stays on PoShLog 2.x.

**Q: Will official extension modules be updated?**
A: Yes — PoShLog.Enrichers, PoShLog.Sinks.Seq, PoShLog.Sinks.EventLog, etc. will receive v3.0-compatible updates.

**Q: My script uses Write-InfoLog, do I need to change anything?**
A: No — all cmdlet names and parameters are unchanged. Just update the module version.

**Q: I need PowerShell 5.1 support, what do I do?**
A: Stay on PoShLog v2.x. It will continue to work but won't receive new features.
