[CmdletBinding()]
param([string]$Configuration = 'Release')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
foreach ($target in 'net472', 'net10.0') {
    $output = Join-Path $root "src/lib/$target"
    dotnet publish "$root/src/dotnet/PoShLog.Core.csproj" -f $target -c $Configuration -o $output --configfile "$PSScriptRoot/nuget.config"
    if ($LASTEXITCODE) { throw "Publishing Core $target failed ($LASTEXITCODE)." }
    foreach ($forbidden in 'System.Management.Automation.dll', 'Serilog.Expressions.dll') {
        if (Get-ChildItem $output -Recurse -File -Filter $forbidden) { throw "Core must not ship $forbidden." }
    }
}
