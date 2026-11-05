#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Manifest,
    [string]$PesterPath,
    [string]$Results = (Join-Path ([IO.Path]::GetTempPath()) 'PoShLog-DesktopTests')
)
$ErrorActionPreference = 'Stop'
if ($PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'Run this script with real Windows PowerShell 5.1 powershell.exe.'
}
$root = Split-Path $PSScriptRoot
$env:POSHLOG_TEST_MANIFEST = (Resolve-Path $Manifest).Path
New-Item $Results -ItemType Directory -Force | Out-Null
if ($PesterPath) { Import-Module $PesterPath -ErrorAction Stop } else { Import-Module Pester -MinimumVersion 5.5.0 -ErrorAction Stop }
$config = New-PesterConfiguration
$config.Run.Path = @('PoShLog.Tests.ps1', 'PoShLog.Ergonomics.Tests.ps1', 'PoShLog.ExtensionCatalog.Tests.ps1', 'PoShLog.IssueFeatures.Tests.ps1', 'PoShLog.CoreHosts.Tests.ps1') |
    ForEach-Object { Join-Path "$root/tests" $_ }
$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $Results 'desktop-pester.xml'
$result = Invoke-Pester -Configuration $config
$reasons = @{
    'DesktopUnsupported.Expressions' = 'Expression filters are phase 2 on Desktop (ADR 0031).'
    'DesktopUnsupported.Extensions' = 'In-repo extensions target net10.0 and are outside Core phase 1.'
    'DesktopUnsupported.PSStyle' = 'PSStyle ANSI rendering is a PowerShell 7 host API.'
}
foreach ($test in $result.Tests | Where-Object Skipped) {
    $reason = @($test.Tag | ForEach-Object { $reasons[$_] }) -join ' '
    if (!$reason.Trim()) { throw "A skipped test needs a reason: $($test.ExpandedPath)" }
    Write-Output "SKIP $($test.ExpandedPath) - $reason"
}
Get-ChildItem "$root/tests" -Filter '*.Tests.ps1' | Where-Object FullName -notin $config.Run.Path.Value |
    ForEach-Object { Write-Output "EXCLUDED $($_.Name) - Extension-only suite requires net10.0 and PowerShell 7.6 (outside Core phase 1)." }
Write-Output "RESULT Desktop $($PSVersionTable.PSVersion) passed=$($result.PassedCount) failed=$($result.FailedCount) skipped=$($result.SkippedCount) total=$($result.TotalCount)"
if ($result.FailedCount -gt 0 -or $result.PassedCount -eq 0) { throw 'Desktop Pester failed.' }
