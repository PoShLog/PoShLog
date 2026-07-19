# Getting started

These instructions will get you a copy of PoShLog up and running.

> **Note:** As of v3.0.0, PoShLog is a **compiled C# binary module** targeting **.NET 8** and requires **PowerShell 7.0+ (PowerShell Core)**. Windows PowerShell 5.1 / Desktop edition is **no longer supported**.

## Prerequisites

### PowerShell 7+

PoShLog requires [PowerShell 7 or later](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell). If you have the [.NET SDK](https://dotnet.microsoft.com/download) installed, you can install PowerShell as a .NET tool:

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

### Stable

To install PoShLog, run the following from a `pwsh` prompt:

```ps1
Install-Module -Name PoShLog
```

Congratulations, you have successfully installed the PoShLog logging module 🚀

### Preview

To install a **non-stable** preview build (published automatically on every push to `master`), run:

```ps1
Install-Module -Name PoShLog -AllowPrerelease
```

*Requires [PowerShellGet](https://www.powershellgallery.com/packages/PowerShellGet) 2.0+.*

## What changed in v3.0.0 (binary module rewrite)

* The module is now implemented as compiled C# `PSCmdlet`/`Cmdlet` classes (`PoShLog.Core.dll`) instead of PowerShell script functions.
* Cmdlet names, parameters, aliases, and pipeline behavior are unchanged — existing scripts using PoShLog continue to work without modification.
* Built on [Serilog](https://serilog.net/) 4.2.0.
* Minimum supported PowerShell version is now **7.0**.

Continue to [Usage](usage.md).
