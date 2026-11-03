# Changelog

All notable changes to PoShLog, newest first. Older releases: see the GitHub releases and `releaseNotes/` in the v2 history.

## 3.0.0 — unreleased

### Features
- PoShLog is now a compiled binary module on Serilog 4 (faster import, no `Add-Type` assembly juggling).
- New cmdlets: `Add-SinkLogger`, `Get-CurrentLogFiles`, `Set-DefaultMessageFormatter`, `Enable-SelfLog`, `Disable-SelfLog`.
- New `Push-LogContextProperty` adds properties to every event logged inside a script block or until its bookmark is disposed (#34).
- New `Get-CompactFormatter` writes CLEF (compact JSON) for Seq and log shippers, with `-Rendered` for the rendered message (#48).
- New extension PoShLog.Sinks.OpenTelemetry 0.1.0: `Add-SinkOpenTelemetry` sends logs over OTLP to Seq, Grafana, .NET Aspire, Datadog, Splunk, Elastic or any OpenTelemetry Collector.
- New extension PoShLog.Sinks.Splunk.Hec 0.1.0: `Add-SinkSplunk` sends logs to a Splunk HTTP Event Collector, as JSON events or raw lines, and accepts the parameter names of the third-party PoShLog.Sinks.Splunk.
- New extension PoShLog.Sinks.Syslog.Rfc5424 0.1.0: `Add-SinkSyslog` sends logs to a syslog server over UDP, TCP or TLS, as RFC 5424 messages with the properties as structured data, or as RFC 3164.
- Any Serilog sink package can be used directly, without a PoShLog wrapper module (see `docs/guides/migration-v3.md`).

### Changes
- Refresh Serilog to 4.4.0, Console to 6.1.1 and File to 7.0.0.
- Add Seq, EventLog, Http and Enrichers 1.1.0 under extensions/ with a shared build script.
- Add CI compatibility checks for source builds and pinned published extensions.
- Publish a selected module through the manual release workflow.
- Requires PowerShell 7.4 or newer; Windows PowerShell 5.1 users stay on 2.x.
- Documentation moved from the wiki into `docs/`, including a v2 → v3 migration guide.
- Internal helpers `Add-PackageTypes` and `Test-PsCore` were never exported.
- `{@Name}` logs a `[pscustomobject]` with its PowerShell properties only and a hashtable as a JSON object; cycles are written as `"[Circular]"`.
- `Start-Logger -Console` no longer adds the PowerShell sink as well; add `-PowerShell` to get both.

### Bug fixes
- Preserve v2 extension compatibility and load shared Serilog dependencies at import.
- Correct the migration guide and restore cmdlet indexes from the committed wiki.
- Logging a `Select-Object` result or another PowerShell object with `{@Name}` no longer produces huge output or hangs (#46).
- Error and Fatal events from the PowerShell sink are shown again and recorded by `Start-Transcript`, like in v2 (#45).
- `Start-Logger -Console` printed every event twice (#28).
- PoShLog.Sinks.OpenTelemetry now refuses to import next to an older Protobuf or gRPC assembly; the error was ignored and the import went on.
