[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('PoShLog', 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.EventLog', 'PoShLog.Enrichers', 'PoShLog.Sinks.Http')]
    [string]$Module
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$source = if ($Module -eq 'PoShLog') { "$root/src" } else { "$root/extensions/$Module" }
if ($Module -ne 'PoShLog') { & "$PSScriptRoot/Build-Extension.ps1" -Module $Module }
$destination = Join-Path $root "artifacts/$Module"
if (Test-Path $destination) {
    throw "Staging directory already exists: $destination. Use a clean release checkout."
}
New-Item -ItemType Directory -Force $destination | Out-Null
Copy-Item "$source/$Module.psd1", "$source/lib" -Destination $destination -Recurse
if ($Module -eq 'PoShLog') {
    Copy-Item "$root/README.md", "$root/LICENSE", "$root/CHANGELOG.md" $destination
} else {
    Copy-Item "$source/$Module.psm1", "$source/functions", "$source/README.md", "$source/LICENSE", "$source/CHANGELOG.md" $destination -Recurse
}
Write-Output "Staged $Module -> $destination"
