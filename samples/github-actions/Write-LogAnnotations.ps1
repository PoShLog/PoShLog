#Requires -Version 7.6
<#
.SYNOPSIS
    Turns the Warning, Error and Fatal events of a CLEF log file into GitHub Actions annotations, and writes a count per
    level to the job summary. Needs no module; run it in a step with `if: always()`.
.EXAMPLE
    ./Write-LogAnnotations.ps1 -Path "$env:RUNNER_TEMP/poshlog/test-json.clef"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    # GitHub shows at most 10 warning and 10 error annotations per step; the rest stay in the log file.
    [int]$MaxAnnotations = 10
)

$ErrorActionPreference = 'Stop'

# Workflow commands end at a line break, so the message escapes '%', CR and LF.
function ConvertTo-CommandValue([string]$Text) {
    $Text.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
}

if (!(Test-Path -LiteralPath $Path)) {
    Write-Output "::warning::No log file at $(ConvertTo-CommandValue $Path); the step before did not start logging."
    exit 0
}

$counts = [ordered]@{ Verbose = 0; Debug = 0; Information = 0; Warning = 0; Error = 0; Fatal = 0 }
$annotations = @{ warning = 0; error = 0 }
foreach ($line in Get-Content -LiteralPath $Path) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $logEvent = $line | ConvertFrom-Json
    # CLEF leaves @l out for Information.
    $level = $logEvent.'@l' ?? 'Information'
    $counts[$level]++
    $command = switch ($level) { 'Warning' { 'warning' } { $_ -in 'Error', 'Fatal' } { 'error' } }
    if (!$command -or $annotations[$command] -ge $MaxAnnotations) { continue }
    $annotations[$command]++
    # -Rendered writes @m; without it, fall back to the template.
    $message = $logEvent.'@m' ?? $logEvent.'@mt'
    if ($logEvent.'@x') { $message += "`n" + $logEvent.'@x' }
    Write-Output "::${command} title=PoShLog ${level}::$(ConvertTo-CommandValue $message)"
}

if ($env:GITHUB_STEP_SUMMARY) {
    $summary = @('### Log events', '', '| Level | Events |', '|---|---:|')
    $summary += $counts.GetEnumerator() | Where-Object Value -gt 0 | ForEach-Object { "| $($_.Key) | $($_.Value) |" }
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $summary
}
