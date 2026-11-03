<#
.SYNOPSIS
	Imports the staged module from artifacts/PoShLog and checks that an event reaches a file sink.
#>
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$log = Join-Path ([IO.Path]::GetTempPath()) "poshlog-smoke-$($PSVersionTable.PSEdition).log"
Remove-Item $log -ErrorAction SilentlyContinue

Import-Module (Join-Path $root 'artifacts\PoShLog\PoShLog.psd1') -Force
New-Logger | Add-SinkFile -Path $log | Start-Logger
Write-InfoLog 'Staged module works on {Edition}' -PropertyValues $PSVersionTable.PSEdition
Close-Logger

$text = Get-Content $log -Raw
Write-Output $text
if ($text -notmatch "Staged module works on `"?$($PSVersionTable.PSEdition)") { throw 'The log event was not written.' }
