#Requires -Version 7.4
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
Import-Module "$root/src/PoShLog.psd1"
$directory = Join-Path $root "artifacts/issue-examples/filter-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $directory -Force | Out-Null
Set-Location $directory
$child = New-Logger | Add-SinkFile -Path './selected.log' -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger -PassThru
try {
    New-Logger | Add-SinkFile -Path './all.log' -OutputTemplate '{Message:lj}{NewLine}' |
        Add-SinkLogger -Logger $child -Filter 'Send = true' | Start-Logger
    Write-InfoLog 'Selected {Send}' -PropertyValues $true
    Write-InfoLog 'Local only {Send}' -PropertyValues $false
} finally { Close-Logger; $child.Dispose() }
'All events:'
Get-Content './all.log'
'Selected events:'
Get-Content './selected.log'
