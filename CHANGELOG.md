# Changelog

All notable changes to PoShLog, newest first. Older releases: see the GitHub releases and `releaseNotes/` in the v2 history.

## 3.0.0 — unreleased

### Features
- PoShLog is now a compiled binary module on Serilog 4 (faster import, no `Add-Type` assembly juggling).
- New cmdlets: `Add-SinkLogger`, `Get-CurrentLogFiles`, `Set-DefaultMessageFormatter`, `Enable-SelfLog`, `Disable-SelfLog`.
- Any Serilog sink package can be used directly, without a PoShLog wrapper module (see `docs/guides/migration-v3.md`).

### Changes
- Requires PowerShell 7.4 or newer; Windows PowerShell 5.1 users stay on 2.x.
- Documentation moved from the wiki into `docs/`, including a v2 → v3 migration guide.
- `Add-PackageTypes` and `Test-PsCore` are removed.

### Bug fixes
- None recorded yet.
