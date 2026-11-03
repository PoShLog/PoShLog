# Compatibility and installation

This page is the single source for which PoShLog and extension versions work together and how to install them. Other
pages link here instead of repeating it. Background: [v2 or v3?](v2-or-v3.md),
[ADR 0003](decisions/0003-keep-the-v2-extension-contract.md), [ADR 0004](decisions/0004-refreshed-extensions-require-poshlog-3.md),
[ADR 0017](decisions/0017-extensions-require-poshlog-2-99-while-core-is-prerelease.md).

## PoShLog

| | PoShLog 3 | PoShLog 2 |
|---|---|---|
| Latest on the PowerShell Gallery | 3.0.0-preview2 (prerelease) | 2.2.0 |
| PowerShell | 7.4+ on Windows, Linux, macOS | Windows PowerShell 5.1 and PowerShell 7 |
| Serilog | 4.4.0 | 2.x |
| Install | `Install-PSResource PoShLog -Prerelease` or `Install-Module PoShLog -AllowPrerelease` | `Install-Module PoShLog -MaximumVersion 2.99` |

> [!IMPORTANT]
> While PoShLog 3 is a prerelease, `Install-Module PoShLog` without `-AllowPrerelease` installs **2.2.0**.

## Extensions

| Module | With PoShLog 2 | With PoShLog 3 | Requires PoShLog |
|---|---|---|---|
| PoShLog.Sinks.Seq | 1.0.0 | 1.0.0, or 2.0.0-preview2 | 1.0.0: 2.0.0+ · 2.0.0-preview2: 3 |
| PoShLog.Sinks.EventLog (Windows) | 1.0.0 | 1.0.0, or 2.0.0-preview2 | 1.0.0: 2.0.0+ · 2.0.0-preview2: 3 |
| PoShLog.Sinks.Http | 1.0.1 | 1.0.1, or 2.0.0-preview2 | 1.0.1: 2.0.0+ · 2.0.0-preview2: 3 |
| PoShLog.Enrichers | 1.0.0 | 1.0.0, or 2.0.0-preview2 | 1.0.0: 2.0.0+ · 2.0.0-preview2: 3 |
| PoShLog.Sinks.OpenTelemetry | — | 0.1.0-preview2 | 3 |
| PoShLog.Sinks.Splunk.Hec | — | 0.1.0-preview2 | 3 |
| PoShLog.Sinks.Syslog.Rfc5424 | — | 0.1.0-preview2 | 3 |
| PoShLog.Sinks.Elastic | — | 0.1.0-preview2 | 3 |

- The published 1.0.x extensions keep working on PoShLog 3. CI checks them against every Core build (the
  `Published` compatibility mode, [ADR 0003](decisions/0003-keep-the-v2-extension-contract.md)).
- Versions 2.0.0 and the new sinks need PowerShell 7.4 and PoShLog 3. On PoShLog 2, stay on 1.0.x. While PoShLog 3 is
  a prerelease they are prereleases too ([ADR 0019](decisions/0019-extensions-ship-as-prereleases-during-the-core-3-preview.md)),
  so `Install-Module <extension>` keeps installing the 1.0.x line.
- "Requires PoShLog 3" is declared as `2.99.0` by GUID while PoShLog 3 is a prerelease, so that package managers can
  resolve the preview ([ADR 0017](decisions/0017-extensions-require-poshlog-2-99-while-core-is-prerelease.md)). No
  PoShLog 2 release reaches 2.99.
- Other authors' modules (`PoShLog.Sinks.Splunk`, `PoShLog.Sinks.Syslog`, …) are checked in CI but not blocking
  ([ADR 0009](decisions/0009-first-party-sinks-third-party-check-non-blocking.md)). See the [sinks page](sinks/README.md).

## Installing the PoShLog 3 preview

```powershell
# PoShLog itself: either package manager works.
Install-PSResource PoShLog -Prerelease
# or
Install-Module PoShLog -AllowPrerelease

# Preview extensions (2.0.0 and the new sinks): use PSResourceGet.
Install-PSResource PoShLog.Sinks.OpenTelemetry -Prerelease
# or let PoShLog pick the prerelease rule (ADR 0021)
Install-PoShLogExtension PoShLog.Sinks.OpenTelemetry
```

- [`Get-PoShLogExtension`](cmdlets/Get-PoShLogExtension.md) lists the extensions that belong to the installed PoShLog
  build with their versions; [`Install-PoShLogExtension`](cmdlets/Install-PoShLogExtension.md) installs them through
  `Install-PSResource` with `-Prerelease` while PoShLog is a prerelease.

- `Install-PSResource` ships with PowerShell 7.4 and newer. The extension command was tested with PSResourceGet 1.2.0;
  if an older version cannot resolve the PoShLog dependency, update it with
  `Install-PSResource Microsoft.PowerShell.PSResourceGet`.
- `Install-Module` (PowerShellGet 2) cannot resolve a prerelease dependency, so it cannot install the preview
  extensions, even when PoShLog 3 is already installed.
- Installing a published 1.0.x extension next to PoShLog 3 (`Install-Module PoShLog.Sinks.Seq`) also installs
  PoShLog 2.2.0 as its dependency. `Import-Module` still loads the newest installed PoShLog, the preview.

## v2 and v3 side by side, and going back

Both lines can stay installed; nothing has to be uninstalled first.

```powershell
Install-Module PoShLog -AllowPrerelease          # adds 3.0.0-preview next to 2.x

Import-Module PoShLog                            # loads the newest: 3.0.0-preview
Import-Module PoShLog -RequiredVersion 2.2.0     # loads 2.2.0 in this session
```

A script that must keep running on v2 pins it:

```powershell
#Requires -Modules @{ ModuleName = 'PoShLog'; RequiredVersion = '2.2.0' }
```

To go back, remove only the preview:

```powershell
Uninstall-Module PoShLog -RequiredVersion 3.0.0-preview2 -AllowPrerelease
# or
Uninstall-PSResource PoShLog -Version 3.0.0-preview2 -Prerelease
```

One PowerShell session holds one PoShLog version. Start a new session to switch.

## How this was verified

On 2026-11-03, each scenario ran in a new `mcr.microsoft.com/powershell:7.4-ubuntu-22.04` container (PowerShell 7.4.6),
with no modules installed beforehand:

- From the PowerShell Gallery: both install commands for PoShLog 3.0.0-preview1, import and one logged event; the plain
  `Install-Module PoShLog` (2.2.0); Seq 1.0.0 next to the preview; 2.2.0 and the preview side by side, the
  `-RequiredVersion` and `#Requires` pins, and both uninstall commands.
- From a local repository with the preview2 packages (Core 3.0.0-preview2, Seq 2.0.0-preview2,
  OpenTelemetry 0.1.0): publish with the dependency check, install the extensions with PSResourceGet 1.2.0, import them,
  and log one event. `build/Test-PackageInstall.ps1` repeats this check in CI.
- From a local repository with Core 3.0.0-preview2: a stable extension with the 2.99.0 floor installs with
  `Install-PSResource` but fails with `Install-Module` ("Unable to find dependent module(s)"); a prerelease extension is
  not offered by either without `-Prerelease` ([ADR 0019](decisions/0019-extensions-ship-as-prereleases-during-the-core-3-preview.md)).

Not verified yet: the preview extensions on the real Gallery (they are not published) and macOS installs. The first
preview2 publish confirms the Gallery case.
