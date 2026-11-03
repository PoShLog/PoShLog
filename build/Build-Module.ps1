<#
.SYNOPSIS
	Builds the v2 PoShLog module without external build modules.
.DESCRIPTION
	Publishes the netstandard2.0 helper library into src/lib and stages the module into artifacts/PoShLog.
	Runs under Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding()]
param(
	[string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'src'
$lib = Join-Path $src 'lib'
$stage = Join-Path $root 'artifacts\PoShLog'

if (Test-Path $lib) { Remove-Item $lib -Recurse -Force }
dotnet publish (Join-Path $src 'dotnet\PoShLog.Core.csproj') -c $Configuration -o $lib --configfile (Join-Path $PSScriptRoot 'nuget.config') -nologo -v q
if ($LASTEXITCODE) { throw 'dotnet publish failed.' }

# PowerShell itself provides System.Management.Automation; only Serilog and the helper library ship.
Get-ChildItem $lib -File | Where-Object { $_.Extension -ne '.dll' -or $_.Name -eq 'System.Management.Automation.dll' } | Remove-Item -Force

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item $stage -ItemType Directory | Out-Null
Copy-Item (Join-Path $src 'functions'), $lib -Destination $stage -Recurse
Copy-Item (Join-Path $src 'PoShLog.psd1'), (Join-Path $src 'PoShLog.psm1'), (Join-Path $root 'README.md'), (Join-Path $root 'LICENSE') -Destination $stage

$manifest = Test-ModuleManifest (Join-Path $stage 'PoShLog.psd1')
Write-Output ('Staged PoShLog {0} in {1}' -f $manifest.Version, $stage)
Get-ChildItem (Join-Path $stage 'lib') -Filter *.dll | ForEach-Object { Write-Output ('  lib/{0}' -f $_.Name) }
