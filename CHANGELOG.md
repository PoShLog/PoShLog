# Changelog

This is the changelog of the **v2 line** (branch `release/2.x`), the script module for Windows PowerShell 5.1 and
PowerShell 7. v3 keeps its own changelog on `master`.

## 2.2.0 — 2026-11-03

### Features
- `Add-SinkLogger` writes events to another logger (sub-logger).
- `Get-Logger` returns the current logger; `Set-DefaultMessageFormatter` sets the template `Get-FormattedMessage` uses.
- `Get-CurrentLogFiles` lists the files the file sinks of the current logger write to.
- `Enable-SelfLog` and `Disable-SelfLog` show Serilog's own diagnostic messages.
- `Add-PackageTypes` and `Test-PsCore` are public, so extension modules can use them.

### Changes
- Serilog updated to 2.10.0.
- Sink functions declare their output type.
- The module is built and tested by GitHub Actions under Windows PowerShell 5.1 and PowerShell 7, and released by
  pushing a `v2.x.y` tag (`build/Build-Module.ps1`, `.github/workflows/ci-v2.yml`, `release-v2.yml`).

### Bug fixes
- Log functions accept multiline pipeline input (#19).
- Errors from `Add-Type` while loading the libraries are logged properly.
- The build no longer writes the XML documentation to an absolute path outside the repository.

## 2.1.1 — 2020-07-13

### Bug fixes
- Fixed `Add-EnrichWithProperty`.
