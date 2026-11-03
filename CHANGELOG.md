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
- New extension PoShLog.Sinks.Elastic 0.1.0: `Add-SinkElasticsearch` sends logs to Elasticsearch or Elastic Cloud data streams as Elastic Common Schema documents, with an API key or a user name and password.
- Recipes for scheduled scripts, GitHub Actions and Pester tests (`docs/recipes/`), with runnable samples under `samples/` that CI runs against the staged package.
- Serilog 4 sink packages can be configured directly as an advanced route, with the constraints listed in `docs/guides/migration-v3.md`.

### Changes
- Require PoShLog 2.99.0 in extensions during the Core 3 preview so prerelease dependencies resolve.
- Publish prereleases through the release workflow with PSResourceGet and dependency validation.
- Add an Ubuntu PowerShell 7.4 Pester CI leg and a macOS module/file-logging smoke check.
- Refresh Serilog to 4.4.0, Console to 6.1.1 and File to 7.0.0.
- Add Seq, EventLog, Http and Enrichers 2.0.0 under extensions/ with a shared build script.
- Refreshed Seq, EventLog, Http and Enrichers 2.0.0 reuse same/newer loaded dependencies and reject older copies with a clear import error (2.x users stay on 1.0.x).
- Add CI compatibility checks for source builds and pinned published extensions.
- Publish a selected module through the manual release workflow.
- Requires PowerShell 7.4 or newer; Windows PowerShell 5.1 users stay on 2.x.
- Documentation moved from the wiki into `docs/`, including a v2 → v3 migration guide and one compatibility and install page (`docs/compatibility.md`) with the tested preview install, side-by-side and rollback commands.
- Internal helpers `Add-PackageTypes` and `Test-PsCore` were never exported.
- `{@Name}` logs a `[pscustomobject]` with its PowerShell properties only and a hashtable as a JSON object; cycles are written as `"[Circular]"`.
- `Start-Logger -Console` no longer adds the PowerShell sink as well; add `-PowerShell` to get both.

### Bug fixes
- Make Convert-LogFunctions syntax-aware and conservative: preserve literal text and Write-Error, report a reviewable diff, honor WhatIf/Confirm, and back up scripts while preserving encoding and line endings.
- Preserve v2 extension compatibility and load shared Serilog dependencies at import.
- Correct the migration guide and restore cmdlet indexes from the committed wiki.
- Logging a `Select-Object` result or another PowerShell object with `{@Name}` no longer produces huge output or hangs (#46).
- Error and Fatal events from the PowerShell sink are shown again and recorded by `Start-Transcript`, like in v2 (#45).
- `Start-Logger -Console` printed every event twice (#28).
- PoShLog.Sinks.OpenTelemetry now refuses to import next to an older Protobuf or gRPC assembly; the error was ignored and the import went on.
