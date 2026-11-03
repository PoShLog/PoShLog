#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'PoShLog'; ModuleVersion = '3.0.0' }
<#
.SYNOPSIS
    Checks that every JSON file under a folder parses. A CI step that writes readable lines to the job log and every
    event as compact JSON (CLEF) to a file, which the workflow uploads as an artifact.
.EXAMPLE
    ./Test-JsonFiles.ps1 -Path ./config -LogPath "$env:RUNNER_TEMP/poshlog/test-json.clef"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [string]$LogPath = (Join-Path ($env:RUNNER_TEMP ?? [IO.Path]::GetTempPath()) 'poshlog/test-json.clef')
)

$ErrorActionPreference = 'Stop'

New-Logger |
    Set-MinimumLevel -Value Debug |
    Add-EnrichWithProperty -Name Workflow -Value ($env:GITHUB_WORKFLOW ?? 'local') |
    Add-EnrichWithProperty -Name RunId -Value ($env:GITHUB_RUN_ID ?? 'local') |
    # The job log adds its own timestamps; Debug events go only to the file.
    Add-SinkConsole -RestrictedToMinimumLevel Information -OutputTemplate '[{Level:u3}] {Message:lj}{NewLine}{Exception}' |
    Add-SinkFile -Path $LogPath -Formatter (Get-CompactFormatter -Rendered) |
    Start-Logger

$exitCode = 0
try {
    $files = @(Get-ChildItem -LiteralPath $Path -Filter '*.json' -File -Recurse)
    Write-InfoLog 'Checking {FileCount} JSON files under {Path}' -PropertyValues $files.Count, $Path
    $invalid = 0
    foreach ($file in $files) {
        $relative = [IO.Path]::GetRelativePath($Path, $file.FullName)
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ([string]::IsNullOrWhiteSpace($text)) {
            Write-WarningLog '{File} is empty' -PropertyValues $relative
            continue
        }
        try {
            $null = $text | ConvertFrom-Json
            Write-DebugLog '{File} is valid' -PropertyValues $relative
        }
        catch {
            $invalid++
            Write-ErrorLog '{File} is not valid JSON: {Reason}' -PropertyValues $relative, $_.Exception.Message
        }
    }
    if ($invalid -gt 0) {
        Write-ErrorLog '{InvalidCount} of {FileCount} files are not valid JSON' -PropertyValues $invalid, $files.Count
        $exitCode = 1
    }
    else {
        Write-InfoLog 'No invalid JSON in {FileCount} files' -PropertyValues $files.Count
    }
}
catch {
    Write-FatalLog 'The check could not run' -ErrorRecord $_
    $exitCode = 2
}
finally {
    Close-Logger
}
# A non-zero exit code fails the step; the log level alone does not.
exit $exitCode
