#Requires -Version 7.6
<#
.SYNOPSIS
    Runs the recipe samples (samples/) against the staged PoShLog package, each in a new pwsh process.
.DESCRIPTION
    Stages PoShLog into artifacts/ unless -ModuleRoot names a folder that already holds a staged PoShLog/. Publish the
    Core assembly to src/lib first (./build/Build-Core.ps1).
#>
[CmdletBinding()]
param(
    [string]$ModuleRoot
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
if (!$ModuleRoot) {
    $ModuleRoot = Join-Path $root 'artifacts'
    if (!(Test-Path (Join-Path $ModuleRoot 'PoShLog/PoShLog.psd1'))) {
        & "$PSScriptRoot/Stage-Module.ps1" -Module PoShLog | Out-Host
    }
}
$env:POSHLOG_RECIPES_MODULES = (Resolve-Path $ModuleRoot).Path

Import-Module Pester -MinimumVersion 5.5.0
$config = New-PesterConfiguration
$config.Run.Path = Join-Path $root 'samples/Recipes.Tests.ps1'
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$result = Invoke-Pester -Configuration $config
if ($result.FailedCount -gt 0 -or $result.PassedCount -eq 0) {
    throw "$($result.FailedCount) recipe check(s) failed."
}
