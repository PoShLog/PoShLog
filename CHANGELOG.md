# Changelog

All notable changes to PoShLog, newest first. Older releases: see the GitHub releases and `releaseNotes/` in the v2 history.

## Unreleased

### Features
- No new features.

### Changes
- `Add-SinkLogger -Filter` and JSON `ByIncludingOnly`/`ByExcluding` filters use an expression engine built into PoShLog. The module no longer ships a separate Serilog.Expressions.dll, so filters cannot conflict with other modules that load their own copy (ADR 0032).
- The module now includes the Apache-2.0 licence and a notice for the incorporated Serilog.Expressions.

### Bug fixes
- None.

## 3.0.0-preview3 — 2026-11-04

### Features
- Conditional sink routing with `Add-SinkLogger -Filter` Serilog expressions (#37, ADR 0027).
- Load a Serilog JSON snapshot with `New-Logger -ConfigurationPath` and compose it with the pipeline (#39, ADR 0028).
- Build custom ANSI and System token colors with `New-ConsoleTheme`; optionally color redirected Console output (#30, ADR 0029).
- New extension PoShLog.Sinks.MSSqlServer 2.0.0-preview3: `Add-SinkMSSqlServer` for SQL Server and Azure SQL with batching, configurable columns and private dependencies that coexist with other modules (MSSqlServer#1, #2, ADR 0030).
- New `Get-PoShLogExtension` lists the first-party extensions with what they do, their commands and the installed version; `-Online` adds the latest Gallery version (ADR 0021).
- New `Install-PoShLogExtension` installs an extension with `Install-PSResource`, adding `-Prerelease` while PoShLog is a prerelease; supports `-WhatIf`, `-Scope` and non-interactive use (ADR 0021).
- A documentation website (`website/`, Starlight) built from `docs/`, with search, light and dark themes and the build version in the footer; it is not published yet (ADR 0022).
- Reference pages for `Add-SinkLogger`, `Get-CurrentLogFiles`, `Set-DefaultMessageFormatter`, `Enable-SelfLog` and `Disable-SelfLog`.
- Guides for moving from `Write-Host` and transcripts or from PSFramework, and an FAQ with troubleshooting.

### Changes
- PoShLog.Enrichers lists its functions in `FunctionsToExport`, and every extension manifest describes the extension in one line.
- Add integration tests against real backends for Gallery releases, fresh builds and stable Windows PowerShell 5.1 modules (ADR 0020).
- Error invocation enrichment keeps command names, script paths and line numbers, but no longer logs argument values and source text (`BoundParameters`, `UnboundArguments`, `Line`, `PositionMessage`, `DisplayScriptPosition`), in text and structured output (ADR 0023).

### Bug fixes
- Resolve `Add-SinkFile -Path` and `Start-Logger -FilePath` against the current PowerShell FileSystem location, including PSDrives (#41, ADR 0026).
- All seven `Write-*Log` commands emit error-only events with an empty message template, including `-PassThru` (ADR 0023).
- Accept constructed `ErrorRecord` instances without invocation metadata (ADR 0023).
- PoShLog.Sinks.Seq, PoShLog.Sinks.Http and PoShLog.Sinks.EventLog 2.0.0-preview3: Seq and Http configure every pipeline input, Http exports `Get-ApiKeyHttpClient`, EventLog binds `-ManageEventSource` as a boolean and supports `-WhatIf` (ADR 0023).

## 3.0.0-preview2 — 2026-11-03

Everything since PoShLog 2.x; 3.0.0-preview1 was published without its own section.

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
- Releases are published by pushing a tag: `v3.*` publishes PoShLog, `<Module>/v<version>` one extension; prereleases go out with PSResourceGet and dependency validation.
- Extensions are published as prereleases (`preview2`) while PoShLog 3 is a prerelease; install them with `Install-PSResource <module> -Prerelease`.
- Add an Ubuntu PowerShell 7.4 Pester CI leg and a macOS module/file-logging smoke check.
- Refresh Serilog to 4.4.0, Console to 6.1.1 and File to 7.0.0.
- Add Seq, EventLog, Http and Enrichers 2.0.0 under extensions/ with a shared build script.
- Refreshed Seq, EventLog, Http and Enrichers 2.0.0 reuse same/newer loaded dependencies and reject older copies with a clear import error (2.x users stay on 1.0.x).
- Add CI compatibility checks for source builds and pinned published extensions.
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
