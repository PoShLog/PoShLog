#Requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('PoShLog', 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.EventLog', 'PoShLog.Enrichers', 'PoShLog.Sinks.Http', 'PoShLog.Sinks.OpenTelemetry', 'PoShLog.Sinks.Splunk.Hec', 'PoShLog.Sinks.Syslog.Rfc5424', 'PoShLog.Sinks.Elastic')]
    [string[]]$Module = @('PoShLog', 'PoShLog.Sinks.Seq', 'PoShLog.Sinks.OpenTelemetry'),
    [ValidatePattern('^[0-9A-Za-z]+$')]
    [string]$Prerelease = 'preview2'
)
$ErrorActionPreference = 'Stop'
# 1.0.x mis-parses dotted names in a local file repository.
Import-Module Microsoft.PowerShell.PSResourceGet -MinimumVersion 1.1.0 -ErrorAction Stop
$scratch = Join-Path ([IO.Path]::GetTempPath()) "poshlog-install-$([guid]::NewGuid().ToString('N'))"
$repository = "PoShLog-Test-$([guid]::NewGuid().ToString('N'))"
$originalModulePath = $env:PSModulePath
$registered = $false
try {
    $stage = Join-Path $scratch 'stage'
    $feed = Join-Path $scratch 'feed'
    New-Item -ItemType Directory -Path $stage, $feed -Force | Out-Null
    # Core is always published first, even when only extensions were requested.
    $modules = @('PoShLog') + @($Module | Where-Object { $_ -ne 'PoShLog' } | Select-Object -Unique)
    foreach ($name in $modules) {
        & "$PSScriptRoot/Stage-Module.ps1" -Module $name -Destination $stage
        $manifest = Join-Path $stage "$name/$name.psd1"
        $data = Import-PowerShellDataFile $manifest
        if (!$data.PrivateData.PSData.Prerelease) {
            # Edit only staged metadata; do not change committed prerelease values.
            $content = [IO.File]::ReadAllText($manifest)
            if ($content -match '(?m)^\s*Prerelease\s*=') {
                $content = [regex]::Replace($content, '(?m)^\s*Prerelease\s*=[^\r\n]*', "            Prerelease = '$Prerelease'")
            } else {
                $content = [regex]::Replace($content, '(?m)^(\s*)PSData\s*=\s*@\{', "`$0`n            Prerelease = '$Prerelease'")
            }
            [IO.File]::WriteAllText($manifest, $content)
            if ((Import-PowerShellDataFile $manifest).PrivateData.PSData.Prerelease -ne $Prerelease) {
                throw "Could not set the staged prerelease label for $name."
            }
        }
    }
    $env:PSModulePath = $stage + [IO.Path]::PathSeparator + $originalModulePath
    Register-PSResourceRepository -Name $repository -Uri $feed -Trusted -ErrorAction Stop
    $registered = $true
    foreach ($name in $modules) {
        Publish-PSResource -Path (Join-Path $stage $name) -Repository $repository -ErrorAction Stop
        Write-Output "Published locally: $name"
    }
    $configuration = Join-Path $scratch 'configuration.json'
    @{ Repository = $repository; Modules = $modules; Destination = (Join-Path $scratch 'saved') } |
        ConvertTo-Json | Set-Content -LiteralPath $configuration
    $child = Join-Path $scratch 'install.ps1'
    @'
param([string]$Configuration)
$ErrorActionPreference = 'Stop'
Import-Module Microsoft.PowerShell.PSResourceGet -MinimumVersion 1.1.0 -ErrorAction Stop
$config = Get-Content -LiteralPath $Configuration -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $config.Destination -Force | Out-Null
$extensions = @($config.Modules | Where-Object { $_ -ne 'PoShLog' })
$targets = if ($extensions.Count) { $extensions } else { @('PoShLog') }
foreach ($name in $targets) {
    Save-PSResource -Name $name -Repository $config.Repository -Prerelease -Path $config.Destination -TrustRepository -ErrorAction Stop
}
$env:PSModulePath = $config.Destination + [IO.Path]::PathSeparator + (Join-Path $PSHOME 'Modules')
foreach ($name in $config.Modules) {
    Import-Module $name -ErrorAction Stop
    $loaded = Get-Module $name
    if (!$loaded -or !$loaded.ModuleBase.StartsWith($config.Destination + [IO.Path]::DirectorySeparatorChar)) {
        throw "Module $name was not imported from the isolated save directory."
    }
    $label = $loaded.PrivateData.PSData.Prerelease
    Write-Output "Resolved: $name $($loaded.Version)$(if ($label) { '-' + $label })"
}
try {
    Start-Logger -Console
    Write-InfoLog -MessageTemplate 'Clean-process package install ready'
} finally {
    Close-Logger
}
'@ | Set-Content -LiteralPath $child
    & (Join-Path $PSHOME 'pwsh') -NoProfile -File $child -Configuration $configuration
    if ($LASTEXITCODE) { throw "Clean-process install failed ($LASTEXITCODE)." }
    Write-Output 'Package install test passed.'
} finally {
    $env:PSModulePath = $originalModulePath
    try {
        if ($registered) { Unregister-PSResourceRepository -Name $repository -ErrorAction Stop }
    } finally {
        if (Test-Path -LiteralPath $scratch) {
            $resolved = (Resolve-Path -LiteralPath $scratch).Path
            $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if ($resolved -ne [IO.Path]::GetFullPath($scratch) -or !$resolved.StartsWith($tempRoot) -or (Split-Path $resolved -Leaf) -notlike 'poshlog-install-*') {
                throw "Refusing to remove an unexpected scratch directory: $resolved"
            }
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
