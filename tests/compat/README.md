# Extension compatibility

Run from the repository root, after `./build/Build-Core.ps1` and building all nine extensions.

```powershell
./tests/compat/Invoke-Compatibility.ps1 -Mode InRepo
```

The suite launches a fresh PowerShell process for each module. It verifies that Core preloads its
shared dependencies, that the extension returns the shared LoggerConfiguration, and that Core's
file sink receives the unique event. Seq and Http must also deliver that event to an HttpListener
on loopback. Enrichers must add environment and process properties. EventLog is Windows-only
and builds its sink configuration without creating an event source or writing to the log.

Published and ThirdParty modes normally run in GitHub Actions. `-AllowLocalPublished` explicitly enables local
diagnosis of first-party published packages only; third-party Gallery modules remain CI-only. They download exact package
versions without resolving Gallery dependencies, then explicitly import freshly built Core first.
The reusable compat.yml workflow runs all three modes on Windows and Linux. InRepo and Published
(our own published extensions) block CI and the manual release workflow. ThirdParty (other
authors' sinks) runs with continue-on-error: failures are annotated but gate nothing (ADR 0009).

The blocking Windows PowerShell Core job additionally stages both target folders and calls
`Invoke-Compatibility.ps1 -Mode Published -Desktop -CoreManifest artifacts/PoShLog/PoShLog.psd1` from PowerShell 7.
Its children are real `powershell.exe` processes. Each published first-party extension runs Core-first and
extension-first. The latter discovers staged Core through its normal `RequiredModules` entry.
Desktop pins EventLog 1.0.1, with configuration-only assertions: it does not create a source or write an Event Log
entry. Published EventLog 1.0.0 reports "not supported on this platform". Published Http 1.0.1 is excluded on Desktop:
`Add-SinkHttp` fails parameter binding because the module loads its bundled Serilog 2 alongside Core's 4.4
([ADR 0034](../../docs/decisions/0034-native-non-durable-http-sink.md)). Modern pins below are unchanged.
Native in-repo Http runs delivery, recovery, saturation, flush, custom contracts, API key and legacy payload checks
in both import orders on each host through `tests/PoShLog.Sinks.Http.Tests.ps1`.
Other refreshed extensions, MSSqlServer isolation and expression tests belong to the modern suite.
`Test-DesktopCoexistence.ps1` checks Az.Accounts 2.19.0, PnP.PowerShell 1.12.0 and PSFramework 1.12.346 in both
orders, with Core file delivery. Both Gallery-based checks run in CI only.

| Published module (mode) | Version | Assertion |
|---|---|---|
| PoShLog.Enrichers (Published) | 1.0.0 | Enriched event in file |
| PoShLog.Sinks.Seq (Published) | 1.0.0 | Event at loopback HTTP listener |
| PoShLog.Sinks.EventLog (Published) | Modern: 1.0.0; Desktop: 1.0.1 | Import and sink configuration only, Windows only |
| PoShLog.Sinks.Http (Published) | 1.0.1, modern only | Event at loopback HTTP listener; unsupported on Desktop with v3 Core |
| PoShLog.Sinks.OpenTelemetry (InRepo build, both modes) | 0.1.0 | Event at loopback OTLP/HTTP `/v1/logs`; also next to Seq (InRepo: refreshed Seq; Published: Seq 1.0.0), each imported first and after, both delivering |
| PoShLog.Sinks.Splunk.Hec (InRepo build, both modes) | 0.1.0 | Event at loopback HEC `/services/collector/event`; also next to Seq, like OpenTelemetry |
| PoShLog.Sinks.Syslog.Rfc5424 (InRepo build, both modes) | 0.1.0 | RFC 5424 datagram at loopback UDP listener; also next to Seq, like OpenTelemetry |
| PoShLog.Sinks.Elastic (InRepo build, both modes) | 0.1.0 | Bulk request at loopback `/logs-poshlog-default/_bulk` (the listener answers the `HEAD /` product check); also next to Seq, like OpenTelemetry |
| PoShLog.Sinks.Exceptionless (Published) | 1.0.0 | Event at loopback HTTP listener; also delivery through `Add-SinkLogger -Filter` and exclusion of a nonmatching event, with filter compilation before and after extension import in fresh processes |
| PoShLog.Sinks.Syslog (ThirdParty) | 1.0.0 | Event at loopback UDP listener |
| PoShLog.Sinks.DataDog (ThirdParty) | 0.1.1 | Event at loopback HTTP listener; skipped on Linux (RootModule case mismatch in its manifest, fails with any PoShLog version) |
| PoShLog.Sinks.ElmahIo (ThirdParty) | 4.0.4 | Import and sink configuration; wrapper has no endpoint override |
| PoShLog.Sinks.Splunk (ThirdParty) | 1.0.4 | Event at loopback HTTP listener |

Each case runs with its own .compat/<marker> folder as the working directory: Seq 1.0.0 passes an empty buffer
file name, ships durably and writes -YYYYMMDD.json and .bookmark there.

For a local InRepo check with an already extracted Exceptionless 1.0.0 package, pass
`-LegacyExceptionlessPath <path/to/PoShLog.Sinks.Exceptionless.psd1>`. Published mode always runs
both filter/import orders in blocking CI on Windows and Linux; it does not need this parameter.

No real credentials are used. Cloud endpoints are not contacted. Only processes and listeners
created by the suite are closed. The driver imposes a per-module timeout; delivery assertions
have a 30-second deadline. Generated files stay in the ignored .compat/ directory.

MSSqlServer 2.0.0-preview3 is built from this repository in every mode. The legacy 1.0.0-preview1 is not a gate:
its missing DLLs and old runtime loader are the defects being replaced. Each mode additionally builds the real NuGet
DI Abstractions 2.2.0 fixture and runs Test-MSSqlServerIsolation.ps1 in fresh processes in both import orders.
InRepo/Published also exercise the new sink next to their respective Seq versions. Actual SQL writes are integration tests.
To run the conflict checks manually:

```powershell
dotnet build tests/compat/fixtures/DependencyInjection22.csproj -c Release --configfile build/nuget.config
./tests/compat/Test-MSSqlServerIsolation.ps1 -Order DependencyFirst
./tests/compat/Test-MSSqlServerIsolation.ps1 -Order SinkFirst
```

Set POSHLOG_SQL_CONNECTION_STRING in the parent process to additionally write and read a row in both orders.
