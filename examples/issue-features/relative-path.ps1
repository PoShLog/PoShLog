#Requires -Version 7.6
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
Import-Module "$root/src/PoShLog.psd1"
$directory = Join-Path $root "artifacts/issue-examples/path-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $directory -Force | Out-Null
Set-Location $directory
New-Logger | Add-SinkFile -Path './logs/example.log' -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger
try { Write-InfoLog 'Relative path works' } finally { Close-Logger }
"Different process directory: $([Environment]::CurrentDirectory -ne $PWD.Path)"
Get-Content './logs/example.log'
