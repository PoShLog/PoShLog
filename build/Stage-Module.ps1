[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('PoShLog', 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.EventLog', 'PoShLog.Enrichers', 'PoShLog.Sinks.Http', 'PoShLog.Sinks.OpenTelemetry', 'PoShLog.Sinks.Splunk.Hec', 'PoShLog.Sinks.Syslog.Rfc5424', 'PoShLog.Sinks.Elastic', 'PoShLog.Sinks.MSSqlServer')]
    [string]$Module,
    [string]$Destination = (Join-Path (Split-Path $PSScriptRoot) 'artifacts')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$source = if ($Module -eq 'PoShLog') { "$root/src" } else { "$root/extensions/$Module" }
if ($Module -eq 'PoShLog') {
    foreach ($target in 'net472', 'net10.0') {
        if (!(Test-Path "$source/lib/$target/PoShLog.Core.dll")) { throw "Build Core $target before staging." }
        if (Get-ChildItem "$source/lib/$target" -Recurse -File | Where-Object Name -in 'Serilog.Expressions.dll', 'System.Management.Automation.dll') {
            throw 'Core must be built without standalone Expressions or PowerShell runtime assemblies before staging.'
        }
        foreach ($notice in 'THIRD-PARTY-NOTICES.txt', 'Serilog.Expressions.LICENSE') {
            if (!(Test-Path "$source/lib/$target/$notice")) { throw "Missing incorporated Expressions notice: $notice" }
        }
    }
}
if ($Module -ne 'PoShLog') { & "$PSScriptRoot/Build-Extension.ps1" -Module $Module }
$destination = Join-Path $Destination $Module
if (Test-Path $destination) {
    throw "Staging directory already exists: $destination. Use a clean release checkout."
}
New-Item -ItemType Directory -Force $destination | Out-Null
Copy-Item "$source/$Module.psd1" -Destination $destination
if ($Module -eq 'PoShLog') {
    foreach ($target in 'net472', 'net10.0') {
        $folder = New-Item "$destination/lib/$target" -ItemType Directory -Force
        Get-ChildItem "$source/lib/$target" -File | Copy-Item -Destination $folder.FullName
    }
    Copy-Item "$source/PoShLog.psm1" $destination
    Copy-Item "$root/README.md", "$root/LICENSE", "$root/CHANGELOG.md" $destination
} else {
    if ($Module -eq 'PoShLog.Sinks.Http') {
        # Copy the shipping allowlist, even when an earlier build left upstream DLLs in lib/.
        foreach ($target in 'net472', 'net10.0') {
            $folder = New-Item "$destination/lib/$target" -ItemType Directory -Force
            Copy-Item "$source/lib/$target/PoShLog.Sinks.Http.dll" $folder.FullName
        }
    } else {
        Copy-Item "$source/lib" $destination -Recurse
    }
    # A module with only compiled cmdlets (PoShLog.Sinks.OpenTelemetry) has no functions/ directory.
    $files = @("$source/$Module.psm1", "$source/functions", "$source/README.md", "$source/LICENSE", "$source/CHANGELOG.md", "$source/THIRD-PARTY-NOTICES.txt", "$source/Serilog.Sinks.Http.LICENSE") | Where-Object { Test-Path $_ }
    Copy-Item $files $destination -Recurse
}
Write-Output "Staged $Module -> $destination"
