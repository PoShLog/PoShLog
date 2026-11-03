# Changelog

This is the changelog of the **v2 line** (branch `release/2.x`), the script module for Windows PowerShell 5.1 and
PowerShell 7. v3 keeps its own changelog on `master`.

## 2.2.1 — 2026-11-03

### Features
- `Add-SinkConsole -Formatter` accepts an `ITextFormatter` such as `Get-JsonFormatter` for structured console
  output (#31, #40, discussion #38), with level switches and standard-error routing. Text and theme options
  remain available in the default parameter set.

### Bug fixes
- Calculated property values from `Select-Object` no longer recursively expand PowerShell wrapper members when
  logged with `{@Property}` (#46). Formatting and `-PassThru` use the unwrapped value.
- The PowerShell sink now transcribes Error and Fatal events as red host information records on Windows
  PowerShell 5.1 as well as PowerShell 7. Enabled Information events use host information records too, while
  hidden Information events are omitted from the transcript (#45).
  The Console sink writes directly to the process console; use the PowerShell sink for transcript support.
- `Start-Logger -Console` adds only the Console sink, avoiding duplicate output (#28). Add `-PowerShell` explicitly
  to select both sinks; `Start-Logger` without sink options still defaults to the PowerShell sink.

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
