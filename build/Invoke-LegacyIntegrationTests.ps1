#Requires -Version 5.1
[CmdletBinding()]
param([string]$ResultsPath)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ne 5) { throw 'Run this script with Windows PowerShell 5.1.' }
$root = Split-Path $PSScriptRoot
if (!$ResultsPath) { $ResultsPath = Join-Path $root 'TestResults/integration-v2' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) "poshlog-v2-$([guid]::NewGuid().ToString('N'))"
$modules = Join-Path $scratch 'Modules'
New-Item -ItemType Directory -Force $modules, $ResultsPath | Out-Null
$ResultsPath = (Resolve-Path $ResultsPath).Path
$previousModulePath = $env:PSModulePath
$previousLocation = Get-Location
$previousDirectory = [Environment]::CurrentDirectory
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Save-Module uses the same PowerShellGet/Gallery resolution as Install-Module, but supports a temp destination.
    # Never bootstrap providers or install packages into CurrentUser/AllUsers folders on the developer's machine.
    if (!(Get-PackageProvider NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
        throw 'NuGet provider must already be available; no user-profile bootstrap is allowed.'
    }
    Save-Module PoShLog -MaximumVersion 2.99 -Path $modules -Repository PSGallery -Force
    Save-Module PoShLog.Sinks.Seq, PoShLog.Sinks.EventLog -Path $modules -Repository PSGallery -Force
    Save-Module Pester -RequiredVersion 5.7.1 -Path $modules -Repository PSGallery -Force
    $env:PSModulePath = $modules + ';' + (Join-Path $PSHOME 'Modules')
    foreach ($name in 'PoShLog', 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.EventLog') {
        $resolved = Get-Module -ListAvailable $name | Sort-Object Version -Descending | Select-Object -First 1
        $major = if ($name -eq 'PoShLog') { 2 } else { 1 }
        if (!$resolved -or $resolved.Version.Major -ne $major -or ($major -eq 1 -and $resolved.Version.Minor -ne 0)) {
            throw "Unexpected stable Gallery version: $name $($resolved.Version)"
        }
        Write-Host "Resolved $name $($resolved.Version)"
    }
    Set-Location $scratch
    [Environment]::CurrentDirectory = $scratch
    $env:POSHLOG_INTEGRATION = '1'
    $env:POSHLOG_LEGACY = '1'
    $env:POSHLOG_LEGACY_TEST_ROOT = "$root/tests/integration"
    $env:POSHLOG_LEGACY_RESULT = "$ResultsPath/legacy.xml"
    # A clean child prevents the host's already imported modules from supplying assemblies or commands.
    & "$PSHOME/powershell.exe" -NoProfile -Command {
        $ErrorActionPreference = 'Stop'
        Import-Module Pester -RequiredVersion 5.7.1
        $config = New-PesterConfiguration
        $config.Run.Path = @(
            "$env:POSHLOG_LEGACY_TEST_ROOT/PoShLog.Integration.Tests.ps1",
            "$env:POSHLOG_LEGACY_TEST_ROOT/legacy/Seq.Integration.Tests.ps1",
            "$env:POSHLOG_LEGACY_TEST_ROOT/PoShLog.Sinks.EventLog.Integration.Tests.ps1"
        )
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'Detailed'
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = $env:POSHLOG_LEGACY_RESULT
        $result = Invoke-Pester -Configuration $config
        if ($result.FailedCount -or $result.FailedContainersCount -or !$result.PassedCount) { exit 1 }
    }
    if ($LASTEXITCODE) { throw 'Legacy integration tests failed.' }
} finally {
    Set-Location $previousLocation
    [Environment]::CurrentDirectory = $previousDirectory
    $env:PSModulePath = $previousModulePath
    Remove-Item Env:POSHLOG_INTEGRATION, Env:POSHLOG_LEGACY, Env:POSHLOG_LEGACY_TEST_ROOT, Env:POSHLOG_LEGACY_RESULT -ErrorAction SilentlyContinue
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    if ((Split-Path $resolvedScratch) -eq [IO.Path]::GetTempPath().TrimEnd('\', '/') -and
        (Split-Path $resolvedScratch -Leaf) -like 'poshlog-v2-*') {
        Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
    }
}
