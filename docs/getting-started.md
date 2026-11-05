# Getting started

These instructions will get you a copy of PoShLog up and running.

> Repository builds contain compiled Core modules for Windows PowerShell 5.1 on .NET Framework 4.7.2+ and
> PowerShell 7.6+ on .NET 10. Desktop support is unreleased and has a bounded phase 1 feature set.
> Published preview1 to preview3 require PowerShell 7.4+. See [compatibility](compatibility.md).

## Prerequisites

### PowerShell 7.6+

PoShLog requires [PowerShell 7.6 or later](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell). If you have the [.NET SDK](https://dotnet.microsoft.com/download) installed, you can install PowerShell as a .NET tool:

```ps1
dotnet tool install --global powershell
pwsh
```

This installs the latest PowerShell and [starts a new session](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh).

Alternatively, follow the official Microsoft installation instructions for your platform:

* [Windows](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)
* [Linux](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)
* [macOS](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos)

## Installation

PoShLog 3 is in preview. From a `pwsh` prompt:

```ps1
Install-Module -Name PoShLog -AllowPrerelease
```

Without `-AllowPrerelease` you get the stable 2.2.0 instead. `Install-PSResource PoShLog -Prerelease` works too.
Extension modules, side-by-side installs with v2 and going back are covered on the
[compatibility page](compatibility.md).

To try Desktop phase 1 from this repository, run `./build/Build-Core.ps1` using the .NET 10 SDK, then import
`./src/PoShLog.psd1` in a clean `powershell.exe` process. Until a Desktop-capable package is published, Gallery users
can keep v2 pinned as described in [v2 or v3](v2-or-v3.md).

## What changed in v3.0.0 (binary module rewrite)

* The module is now implemented as compiled C# `PSCmdlet`/`Cmdlet` classes (`PoShLog.Core.dll`) instead of PowerShell script functions.
* Cmdlet names, parameters, aliases, and pipeline behavior are unchanged — existing scripts using PoShLog continue to work without modification.
* Built on [Serilog](https://serilog.net/) 4.4.0.
* Core hosts require PowerShell 7.6+. Desktop hosts require Windows PowerShell 5.1 and .NET Framework 4.7.2+.

Continue to [Usage](usage.md), or start from a [recipe](recipes/README.md) for a scheduled script, GitHub Actions
or Pester tests.
