# 0033 — v3 targets net10.0 and PowerShell 7.6+

- **Status:** accepted (Tomáš, 2026-11-04)
- **Date:** 2026-11-04
- **Supersedes:** [0001](0001-binary-module-net8-powershell-7-4.md)

## Context

ADR 0001 chose `net8.0` and `PowerShellVersion = '7.4'`, because `net8.0` was the lowest runtime among the PowerShell
versions in support: 7.4 (.NET 8), 7.5 (.NET 9) and 7.6 (.NET 10). That was the stated exception to the global
`net10.0` rule, and 0001 said that moving to a newer target would be a new record once 7.4 and 7.5 were gone.

.NET 8 and .NET 9 reach end of support on 2026-11-10, and PowerShell 7.4 and 7.5 go with them. After that date the
supported PowerShell 7 hosts are 7.6 LTS and newer, all on .NET 10 or later. The external constraint behind 0001 is
gone, and the contributor working on the Windows PowerShell 5.1 build (ADR 0031) raised the same point.

The published 3.0.0-preview1 to preview3 packages declare 7.4 and keep working there; this record changes the builds
after preview3.

## Decision

- Core, every first-party extension under `extensions/` (including the MSSqlServer worker) and the test projects
  target **`net10.0`**. The PowerShell reference is a compile-only `Microsoft.PowerShell.SDK` **7.6.9**
  (`ExcludeAssets="runtime"`, `PrivateAssets="all"`), the current 7.6 patch (patches add no API, and it avoids vulnerable transitive packages in the test projects); test projects use the same version
  at runtime.
- Every manifest declares **`PowerShellVersion = '7.6'`**. `CompatiblePSEditions`, `RequiredModules` and the
  extension version policy of ADR 0004 and ADR 0017 are unchanged.
- CI builds with the .NET 10 SDK. The minimum-host Pester job pins PowerShell **7.6.x** and fails when it runs
  anything else; the other jobs use the runner's PowerShell (7.6.9 on the hosted images on 2026-11-04).
- Users on PowerShell 7.4 or 7.5 stay on PoShLog 2.x until they move to
  7.6. Windows PowerShell 5.1 users stay on 2.x until the Desktop build of ADR 0031 ships.
- Everything else in 0001 still holds: v3 is a binary module, `CompatiblePSEditions = 'Core'` for now, and every
  extension shares Core's Serilog major version in the default load context.

## Alternatives considered

- **Keep `net8.0` and 7.4.** A `net8.0` assembly still loads on .NET 10, so this would keep working. But it keeps a
  target whose runtime is out of support, keeps a CI leg for an unsupported PowerShell and departs from the global
  rule without a constraint to justify it.
- **`net9.0` / PowerShell 7.5.** .NET 9 reaches end of support on the same day as .NET 8; it gains nothing.
- **Declare 7.6 in the manifests but keep building `net8.0`.** It avoids the TFM change, but it hides the real
  requirement and still tests against an out-of-support SDK.

## Consequences

- This is a breaking change for anyone on PowerShell 7.4 or 7.5: the next release no longer installs there. The
  CHANGELOGs, `docs/compatibility.md`, `docs/v2-or-v3.md` and the migration guide say so.
- v3 code can use .NET 10 APIs and C# 14. The Desktop build (ADR 0031) becomes `net472;net10.0`, so any such API in
  shared code needs a Desktop fallback.
- Third-party extensions built for `net8.0` or `netstandard2.0` still load into v3; the extension contract of ADR 0003
  does not change.
- When PowerShell 7.6 nears its end of support, moving the floor again is a new record that supersedes this one.
