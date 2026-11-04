[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('PoShLog.Sinks.Seq', 'PoShLog.Sinks.EventLog', 'PoShLog.Enrichers', 'PoShLog.Sinks.Http', 'PoShLog.Sinks.OpenTelemetry', 'PoShLog.Sinks.Splunk.Hec', 'PoShLog.Sinks.Syslog.Rfc5424', 'PoShLog.Sinks.Elastic', 'PoShLog.Sinks.MSSqlServer')]
    [string]$Module,
    [string]$Configuration = 'Release'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$directory = Join-Path $root "extensions/$Module"
# Stage first: shared Core assemblies must never enter the module's shipping lib.
$staging = Join-Path $directory 'obj/publish'
dotnet publish "$directory/Dependencies.csproj" -c $Configuration -o $staging --configfile "$PSScriptRoot/nuget.config"
if ($LASTEXITCODE) { throw "Publishing $Module failed ($LASTEXITCODE)." }
$lib = Join-Path $directory 'lib'
New-Item -ItemType Directory -Force $lib | Out-Null
Get-ChildItem $lib -File | Remove-Item
$shared = @('Serilog.dll', 'Serilog.Sinks.File.dll', 'Serilog.Sinks.Console.dll', 'System.Management.Automation.dll')
Get-ChildItem $staging -File -Filter '*.dll' |
    Where-Object { $_.Name -notin $shared -and ($_.Name -ne 'Dependencies.dll') } |
    Copy-Item -Destination $lib
# EventLog is Windows-only. Ship its implementation, rather than the portable
# platform-not-supported facade, even when the package is built on Linux.
if ($Module -eq 'PoShLog.Sinks.EventLog') {
    # Publish keeps only the package's runtime folder that matches the target framework, whatever its name.
    Get-ChildItem "$staging/runtimes/win/lib/*/*.dll" -File |
        Copy-Item -Destination $lib -Force
}
if ($Module -eq 'PoShLog.Sinks.MSSqlServer') {
    # Preserve deps.json and all RID assets: SqlClient's root DLL is a portable facade.
    $private = Join-Path $lib 'private'
    dotnet publish "$directory/Private/Worker.csproj" -c $Configuration -o $private --configfile "$PSScriptRoot/nuget.config"
    if ($LASTEXITCODE) { throw 'Publishing the isolated MSSqlServer worker failed.' }
    # Serilog is always supplied by Core, including inside the private context.
    $sharedSerilog = Join-Path $private 'Serilog.dll'
    if (Test-Path $sharedSerilog) { Remove-Item -LiteralPath $sharedSerilog }
    if (!(Test-Path "$private/runtimes/win-x64/native/Microsoft.Data.SqlClient.SNI.dll")) {
        throw 'Missing win-x64 SQL Server native SNI asset.'
    }
    # Linux SqlClient uses managed SNI; no native Linux SNI package is required.
}
Write-Output "Built $Module -> $lib"
