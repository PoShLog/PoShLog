[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('PoShLog', 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.EventLog', 'PoShLog.Enrichers', 'PoShLog.Sinks.Http', 'PoShLog.Sinks.OpenTelemetry', 'PoShLog.Sinks.Splunk.Hec', 'PoShLog.Sinks.Syslog.Rfc5424', 'PoShLog.Sinks.Elastic')]
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
    # A module with only compiled cmdlets (PoShLog.Sinks.OpenTelemetry) has no functions/ directory.
    $files = @("$source/$Module.psm1", "$source/functions", "$source/README.md", "$source/LICENSE", "$source/CHANGELOG.md") | Where-Object { Test-Path $_ }
    Copy-Item $files $destination -Recurse
}
Write-Output "Staged $Module -> $destination"
