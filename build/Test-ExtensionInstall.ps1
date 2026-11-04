#Requires -Version 7.6
<#
.SYNOPSIS
    Checks Install-PoShLogExtension end to end in a clean environment: a local repository with the staged packages, and a
    new pwsh process whose home directory is a scratch folder, so nothing is installed for the real user.
.DESCRIPTION
    Linux and macOS only: PSResourceGet's CurrentUser scope and repository list follow HOME there. On Windows, run it in
    a container, for example:

        docker run --rm -v "${PWD}:/repo" -v "<stage>:/stage" -v "<PSResourceGet module folder>:/psrg" `
            mcr.microsoft.com/dotnet/sdk:10.0 `
            pwsh -File /repo/build/Test-ExtensionInstall.ps1 -StageRoot /stage -PSResourceGetPath /psrg

    The staged packages are published under the repository name 'PoShLog-Local', which exists only in the scratch home.
.PARAMETER StageRoot
    A folder with staged PoShLog and extension modules (Stage-Module.ps1 -Destination). Staged into a scratch folder when
    omitted; that needs Core published to src/lib and the dotnet SDK for the extension.
.PARAMETER PSResourceGetPath
    The Microsoft.PowerShell.PSResourceGet module folder to use in the clean process; 1.0.x mis-parses dotted names in a
    local file repository. Defaults to the newest one available.
#>
[CmdletBinding()]
param(
    [string]$StageRoot,
    [string]$Extension = 'PoShLog.Sinks.Seq',
    [string]$PSResourceGetPath
)
$ErrorActionPreference = 'Stop'
if ($IsWindows) {
    throw 'Test-ExtensionInstall.ps1 isolates the install through HOME, which works on Linux and macOS only. Run it in a container on Windows (see Get-Help).'
}
if (!$PSResourceGetPath) {
    $PSResourceGetPath = (Get-Module Microsoft.PowerShell.PSResourceGet -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase
}
$scratch = Join-Path ([IO.Path]::GetTempPath()) "poshlog-extinstall-$([guid]::NewGuid().ToString('N'))"
try {
    if (!$StageRoot) {
        $StageRoot = Join-Path $scratch 'stage'
        foreach ($name in 'PoShLog', $Extension) {
            & "$PSScriptRoot/Stage-Module.ps1" -Module $name -Destination $StageRoot | Out-Host
        }
    }
    $cleanHome = Join-Path $scratch 'home'
    New-Item -ItemType Directory -Path $cleanHome, (Join-Path $scratch 'feed') -Force | Out-Null
    $child = Join-Path $scratch 'install.ps1'
    @'
param([string]$StageRoot, [string]$Feed, [string]$Extension, [string]$PSResourceGetPath)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSResourceGetPath 'Microsoft.PowerShell.PSResourceGet.psd1') -ErrorAction Stop
Write-Output "PSResourceGet $((Get-Module Microsoft.PowerShell.PSResourceGet).Version)"
if (Get-PSResource -Name PoShLog*, $Extension -ErrorAction SilentlyContinue) { throw 'The clean home already has PoShLog installed.' }
Register-PSResourceRepository -Name PoShLog-Local -Uri $Feed -Trusted
$modulePath = $env:PSModulePath
# Publishing validates the extension's RequiredModules, so the staged Core has to be findable only while publishing.
$env:PSModulePath = $StageRoot + [IO.Path]::PathSeparator + $modulePath
foreach ($name in 'PoShLog', $Extension) {
    Publish-PSResource -Path (Join-Path $StageRoot $name) -Repository PoShLog-Local
}
$env:PSModulePath = $modulePath

# Core is imported from the stage, not installed: the extension has to bring it as its dependency.
Import-Module (Join-Path $StageRoot 'PoShLog/PoShLog.psd1')
$listed = Get-PoShLogExtension -Name $Extension
if ($listed.InstalledVersion) { throw "$Extension is listed as installed ($($listed.InstalledVersion)) before the install." }

Install-PoShLogExtension -Name $Extension -Repository PoShLog-Local -WhatIf
if (Get-PSResource -Name $Extension -ErrorAction SilentlyContinue) { throw '-WhatIf installed the extension.' }

$installed = @(Install-PoShLogExtension -Name $Extension -Repository PoShLog-Local -PassThru)
$installed | ForEach-Object { Write-Output "Installed: $($_.Name) $($_.Version)$(if ($_.Prerelease) { '-' + $_.Prerelease })" }
$resources = @(Get-PSResource -Name 'PoShLog', $Extension)
foreach ($name in 'PoShLog', $Extension) {
    $resource = $resources | Where-Object Name -eq $name
    if (!$resource) { throw "$name was not installed." }
    if (!$resource.Prerelease) { throw "$name was installed without a prerelease label: $($resource.Version)." }
    if (!$resource.InstalledLocation.StartsWith($HOME)) { throw "$name was installed outside the clean home: $($resource.InstalledLocation)." }
}
$listed = Get-PoShLogExtension -Name $Extension
if ($listed.InstalledVersion -ne $listed.Version) { throw "Get-PoShLogExtension reports $($listed.InstalledVersion), expected $($listed.Version)." }
Write-Output "Listed: $($listed.Name) installed $($listed.InstalledVersion)"
'@ | Set-Content -LiteralPath $child

    $saved = @{}
    # A new HOME moves PSResourceGet's CurrentUser scope and repository list; an unset PSModulePath gets the defaults
    # under that HOME.
    $environment = @{ HOME = $cleanHome; XDG_DATA_HOME = $null; XDG_CONFIG_HOME = $null; XDG_CACHE_HOME = $null; PSModulePath = $null }
    foreach ($name in $environment.Keys) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name, $environment[$name])
    }
    try {
        & (Join-Path $PSHOME 'pwsh') -NoProfile -NonInteractive -File $child -StageRoot $StageRoot -Feed (Join-Path $scratch 'feed') -Extension $Extension -PSResourceGetPath $PSResourceGetPath
        if ($LASTEXITCODE) { throw "The clean-process extension install failed ($LASTEXITCODE)." }
    }
    finally {
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    }
    Write-Output 'Extension install test passed.'
}
finally {
    if (Test-Path -LiteralPath $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
}
