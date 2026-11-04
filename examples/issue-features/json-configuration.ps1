#Requires -Version 7.6
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
Import-Module "$root/src/PoShLog.psd1"
$directory = Join-Path $root "artifacts/issue-examples/json-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $directory -Force | Out-Null
Set-Location $directory
@'
{
  "Serilog": {
    "MinimumLevel": "Warning",
    "Properties": { "Application": "backup" },
    "WriteTo": [{ "Name": "File", "Args": { "path": "./configured.log", "outputTemplate": "{Application} {Message:lj}{NewLine}" } }]
  }
}
'@ | Set-Content './logging.json'
New-Logger -ConfigurationPath './logging.json' | Start-Logger
try {
    Write-InfoLog 'Below minimum'
    Write-WarningLog 'Configured from JSON'
} finally { Close-Logger }
Get-Content './configured.log'
