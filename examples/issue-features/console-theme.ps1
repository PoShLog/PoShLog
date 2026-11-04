#Requires -Version 7.6
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
Import-Module "$root/src/PoShLog.psd1"
# This example deliberately demonstrates ANSI output, including when captured by a test runner.
[Environment]::SetEnvironmentVariable('NO_COLOR', $null)
$PSStyle.OutputRendering = 'Ansi'
$theme = New-ConsoleTheme -AnsiStyles @{ String = "`e[32m"; Number = "`e[36m" }
New-Logger | Add-SinkConsole -Theme $theme -ApplyThemeToRedirectedOutput -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger
try { Write-InfoLog 'User {Name} has {Count} items' -PropertyValues 'Ada', 3 } finally { Close-Logger }
