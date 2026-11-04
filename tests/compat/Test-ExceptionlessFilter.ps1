#Requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModulePath,
    [Parameter(Mandatory)][ValidateSet('FilterFirst', 'ExtensionFirst')][string]$Order
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
Import-Module "$root/src/PoShLog.psd1"
if ((Import-PowerShellDataFile $ModulePath).ModuleVersion -ne [version]'1.0.0') {
    throw 'This regression check requires published Exceptionless 1.0.0.'
}
function Initialize-Filter {
    $child = New-Logger | Start-Logger -PassThru
    try {
        New-Logger | Add-SinkLogger -Logger $child -Filter 'Send = true' | Start-Logger
    } finally { Close-Logger; $child.Dispose() }
}
if ($Order -eq 'FilterFirst') { Initialize-Filter }
Import-Module (Resolve-Path $ModulePath)
if ($Order -eq 'ExtensionFirst') { Initialize-Filter }
$helper = 'Serilog.LoggerSinkConfigurationExtensions' -as [type]
if (!$helper -or $helper.Assembly.GetName().Name -eq 'PoShLog.Core') {
    throw 'PowerShell did not resolve the Exceptionless helper.'
}
Add-Type -Path "$PSScriptRoot/CompatHttpListener.cs"
$listener = [CompatHttpListener]::new()
$child = $null
$marker = "filter-$([guid]::NewGuid().ToString('N'))"
try {
    $child = New-Logger | Add-SinkExceptionless -ApiKey 'compat-placeholder-key' -ServerUrl $listener.Url | Start-Logger -PassThru
    New-Logger | Add-SinkLogger -Logger $child -Filter 'Send = true' | Start-Logger
    Write-InfoLog "$marker-included {Send}" -PropertyValues $true
    Write-InfoLog "$marker-excluded {Send}" -PropertyValues $false
    Close-Logger
    $deadline = [datetime]::UtcNow.AddSeconds(30)
    do {
        $body = $listener.Bodies.ToArray() -join "`n"
        if ($body.Contains("$marker-included")) { break }
        Start-Sleep -Milliseconds 100
    } while ([datetime]::UtcNow -lt $deadline)
    if (!$body.Contains("$marker-included")) { throw 'Exceptionless did not deliver the filtered event within 30 seconds.' }
    $child.Dispose()
    [Exceptionless.ExceptionlessClient]::Default.ProcessQueueAsync().GetAwaiter().GetResult() | Out-Null
    $body = $listener.Bodies.ToArray() -join "`n"
    if ($body.Contains("$marker-excluded")) { throw 'Exceptionless received an excluded event.' }
    "PASS Exceptionless 1.0.0 with -Filter: HTTP delivery; excluded event absent; order=$Order; host=$($PSVersionTable.PSVersion)"
} finally {
    Close-Logger
    if ($child) { $child.Dispose() }
    $listener.Dispose()
}
