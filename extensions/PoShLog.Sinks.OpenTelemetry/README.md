# PoShLog.Sinks.OpenTelemetry

An OpenTelemetry (OTLP) sink extension for PoShLog over
[Serilog.Sinks.OpenTelemetry](https://github.com/serilog/serilog-sinks-opentelemetry). Version 0.1.0 requires
PowerShell 7.4+ and PoShLog 3.0.0 (by GUID). Core supplies the shared Serilog assembly; `lib/` ships the sink, Protobuf
and gRPC.

Build from the repository root:

```powershell
./build/Build-Extension.ps1 -Module PoShLog.Sinks.OpenTelemetry
Import-Module ./src/PoShLog.psd1
Import-Module ./extensions/PoShLog.Sinks.OpenTelemetry/PoShLog.Sinks.OpenTelemetry.psd1
New-Logger | Add-SinkOpenTelemetry -Endpoint 'http://localhost:4318' -ServiceName 'demo' | Start-Logger
Write-InfoLog 'Hello from OTLP'
Close-Logger
```

`Add-SinkOpenTelemetry` is a compiled cmdlet (`Cmdlets/`); `OpenTelemetrySinkSettings.cs` maps its parameters and the
`OTEL_*` environment variables to the package's options. Parameters, environment rules and setups for Seq, Aspire,
Grafana, Datadog, Splunk and Elastic: [docs/sinks/Add-SinkOpenTelemetry.md](../../docs/sinks/Add-SinkOpenTelemetry.md).
Design: [ADR 0012](../../docs/decisions/0012-otlp-sink-design.md).

Tests: `tests/PoShLog.Sinks.OpenTelemetry.Tests` (xUnit, with a local OTLP/HTTP and gRPC receiver),
`tests/PoShLog.Sinks.OpenTelemetry.Tests.ps1` (Pester) and the compatibility suite, which also loads the sink next to
PoShLog.Sinks.Seq.
