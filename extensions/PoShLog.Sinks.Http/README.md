# PoShLog.Sinks.Http

An HTTP sink extension for PoShLog. Version 2.0.0 requires PowerShell 7.4+ and Core edition.
Version 2.0.0 requires PoShLog 2.99.0 by GUID; PoShLog 2.x users stay on 1.0.x. Core supplies the shared Serilog assembly.

Build from the repository root:

```powershell
./build/Build-Extension.ps1 -Module PoShLog.Sinks.Http
Import-Module ./src/PoShLog.psd1
Import-Module ./extensions/PoShLog.Sinks.Http/PoShLog.Sinks.Http.psd1
New-Logger | Add-SinkHttp -RequestUri 'http://localhost:8080/events' | Start-Logger
Write-InfoLog 'Hello from Http'
Close-Logger
```

Add-SinkHttp keeps its original parameters: LoggerConfig, RequestUri, BatchPostingLimit,
QueueLimit, Period, Formatter, BatchFormatter, RestrictedToMinimumLevel, HttpClient and Configuration.
QueueLimit still counts events. Serilog 4 provides batching; Serilog.Sinks.Http provides the
HTTP client and formatter interfaces. Get-ApiKeyHttpClient returns a compiled client implementation
that sends the X-Api-Key header and supports the current streaming HTTP interface.

See the [extension build guide](../README.md) and [migration guide](../../docs/guides/migration-v3.md).
