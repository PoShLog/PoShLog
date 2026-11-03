# Changelog

All notable changes to PoShLog, newest first. Older releases: see the GitHub releases and `releaseNotes/` in the v2 history.

## 3.0.0 — unreleased

### Features
- PoShLog is now a compiled binary module on Serilog 4 (faster import, no `Add-Type` assembly juggling).
- New cmdlets: `Add-SinkLogger`, `Get-CurrentLogFiles`, `Set-DefaultMessageFormatter`, `Enable-SelfLog`, `Disable-SelfLog`.
- New `Get-CompactFormatter` writes CLEF (compact JSON) for Seq and log shippers, with `-Rendered` for the rendered message (#48).
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

### Bug fixes
- Preserve v2 extension compatibility and load shared Serilog dependencies at import.
- Correct the migration guide and restore cmdlet indexes from the committed wiki.
- Logging a `Select-Object` result or another PowerShell object with `{@Name}` no longer produces huge output or hangs (#46).
