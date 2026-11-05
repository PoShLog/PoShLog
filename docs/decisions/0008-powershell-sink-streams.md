# 0008 — The PowerShell sink shows Error and Fatal like Write-Host

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03

## Context

Issue #45: events appear on the console but not in the `Start-Transcript` file, or the other way round. A probe on
PowerShell 7.6 showed what the transcript records:

| Output | Console | Transcript |
|---|---|---|
| `Write-Information` hidden by `$InformationPreference` | no | no |
| `Write-Information -InformationAction Continue` | yes | yes |
| `Write-Host`, `Write-Warning`, shown `Write-Verbose` | yes | yes |
| `[Console]::WriteLine` (the Console sink) | yes | no |
| An information record tagged `PSHOST` | always | yes |

v2 wrote Error and Fatal events with `Write-Information -InformationAction Continue`, so they were always shown and
transcribed. The v3 port dropped the `Continue`, so Error and Fatal events were hidden by the default
`$InformationPreference` (SilentlyContinue): a regression.

Issue #28: `Start-Logger -Console` also added the PowerShell sink, so in a console every event was printed twice.

## Decision

- **Error and Fatal events go to the information stream as a red `HostInformationMessage` tagged `PSHOST`**, the way
  `Write-Host` writes. They are always displayed and transcribed, can be redirected with `6>` and captured with
  `-InformationVariable`. When the `Write-*Log` call has an explicit `-InformationAction`, the tag is left out and
  that action decides. Verbose, Debug, Information and Warning keep their streams and preferences.
- Every record the sink writes carries the source `PoShLog`.
- **`Start-Logger` adds the PowerShell sink only when `-PowerShell` is given, or when no sink switch and no
  `-FilePath` is given.** `-Console` alone adds only the console sink.
- The Console sink keeps writing to the process console; its page says it is not transcribed and points to the
  PowerShell sink.

## Alternatives considered

- **Write Error/Fatal as `ErrorRecord`s (`WriteError`).** It is the natural stream, but under
  `$ErrorActionPreference = 'Stop'` logging an error would terminate the script, it adds to `$Error`, and it marks
  `$?` false. A logging call must not change control flow.
- **`-InformationAction Continue` as in v2.** The cmdlet cannot set its own preference after binding; emulating it
  means writing to the host, which skips redirection and `-InformationVariable`. The `PSHOST` tag gives the same
  visible result through the normal stream.
- **Write Error/Fatal to the warning stream.** It would show and transcribe them, but as `WARNING:` lines, which is
  misleading, and `$WarningPreference` would hide errors.
- **Make the Console sink write through the PowerShell host.** It would change the documented behaviour of a sink
  that wraps `Serilog.Sinks.Console`, and break its themes and `-StandardErrorFromLevel`.
- **Keep `-Console` adding both sinks and only document it.** The double output is what users reported as a bug.

## Consequences

- Console and transcript agree for every level that is shown. The Console sink stays out of transcripts by design.
- Scripts that relied on hiding Error/Fatal through `$InformationPreference` now see them; they can pass
  `-InformationAction SilentlyContinue` or redirect `6>`. This restores v2 behaviour and goes into the CHANGELOG.
- `Start-Logger -Console` users who also wanted PowerShell streams add `-PowerShell`. A changed default, listed under
  Changes.
- The transcript behaviour is verified by a Pester test in a child `pwsh` on Windows; the Linux CI run is the first
  check on another platform.

**Note (2026-11-05):** this decision and its probe cover PowerShell 7.6+. On Windows PowerShell 5.1 the same sink
displays Error and Fatal events but the transcript omits them, and it records suppressed information events; see
[ADR 0031](0031-windows-powershell-desktop-support.md), Consequences. The decision itself stands.
