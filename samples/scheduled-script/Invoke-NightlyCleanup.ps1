#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'PoShLog'; ModuleVersion = '3.0.0' }
<#
.SYNOPSIS
    Removes files older than a number of days. A scheduled job (Task Scheduler, cron) that logs to the console and to a
    daily rolling file, and reports its result as an exit code.
.EXAMPLE
    pwsh -NoProfile -NonInteractive -File ./Invoke-NightlyCleanup.ps1 -Path D:\Exports -OlderThanDays 30
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [int]$OlderThanDays = 30,

    # Absolute by default: a scheduled task starts in C:\Windows\System32 and cron in the home directory.
    [string]$LogDirectory = (Join-Path $PSScriptRoot 'logs')
)

$ErrorActionPreference = 'Stop'

New-Logger |
    Set-MinimumLevel -Value Information |
    Add-EnrichWithProperty -Name Job -Value 'nightly-cleanup' |
    Add-SinkConsole |
    Add-SinkFile -Path (Join-Path $LogDirectory 'nightly-cleanup-.log') -RollingInterval Day -RetainedFileCountLimit 14 `
        -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj} {Properties:j}{NewLine}{Exception}' |
    Start-Logger

# 0 = done, 1 = failed. Set it in the script and exit after the finally block, so Close-Logger always runs first.
$exitCode = 0
try {
    Write-InfoLog 'Removing files older than {Days} days from {Path}' -PropertyValues $OlderThanDays, $Path
    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    $files = @(Get-ChildItem -LiteralPath $Path -File -Recurse | Where-Object LastWriteTime -lt $cutoff)
    $bytes = 0L
    foreach ($file in $files) {
        Remove-Item -LiteralPath $file.FullName
        $bytes += $file.Length
        Write-DebugLog 'Removed {File}' -PropertyValues $file.FullName
    }
    Write-InfoLog 'Removed {FileCount} files ({Bytes} bytes)' -PropertyValues $files.Count, $bytes
}
catch {
    Write-FatalLog 'Cleanup of {Path} failed' -PropertyValues $Path -ErrorRecord $_
    $exitCode = 1
}
finally {
    # Flushes the file. Without it, the last events of a short script can be lost.
    Close-Logger
}
exit $exitCode
