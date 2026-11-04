# Changelog

## Unreleased

### Features
- No new features.

### Changes
- Requires PowerShell 7.6 or newer and is built for .NET 10 (ADR 0033). This is a breaking change on PowerShell 7.4 and 7.5: stay on the previous version there, or on PoShLog 2.x with the 1.0.x extensions.

### Bug fixes
- None.

## 0.1.0-preview2 — 2026-11-03

### Features
- New `Add-SinkOpenTelemetry` sends log events over OTLP (HTTP/protobuf or gRPC) to an OpenTelemetry Collector, Seq,
  Grafana, .NET Aspire, the Datadog Agent, Splunk or Elastic.
- Headers, resource attributes, `-ServiceName`, batching (`-BatchSizeLimit`, `-Period`, `-QueueLimit`), level filter
  and a custom HTTP handler.
- The standard `OTEL_*` variables fill in what the parameters leave out; `-IgnoreEnvironment` turns them off.

### Changes
- Requires PoShLog 2.99.0 and PowerShell 7.4 or newer.
- OTLP/HTTP on port 4318 is the default, not the Serilog package's gRPC on 4317.

### Bug fixes
- A parameter always wins over an `OTEL_*` variable; the Serilog package let `OTEL_EXPORTER_OTLP_ENDPOINT` replace an
  explicit endpoint.
- The module refuses to import next to an older Protobuf or gRPC assembly loaded by another module; the error was
  ignored and the import went on.
