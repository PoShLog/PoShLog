# Capturing Console Output

A common question is how to capture **all PowerShell output** (including external commands and unhandled errors) into Serilog logs without modifying every line of your script.

## Capturing Unhandled Errors with `trap`

Use PowerShell's `trap` statement to catch terminating errors:

```powershell
Import-Module PoShLog

New-Logger |
    Add-SinkConsole |
    Add-SinkFile -Path 'C:\Logs\script.log' |
    Start-Logger

trap {
    Write-ErrorLog -MessageTemplate $_.Exception.Message -ErrorRecord $_
    continue
}

# Your script — errors will be captured automatically
Get-ChildItem -Path 'C:\NonExistent' -ErrorAction Stop
1 / $null

Close-Logger
```

## Capturing External Command Output

External commands (e.g., `dotnet build`, `git`) write to stdout/stderr which PowerShell doesn't automatically route to Serilog. Here are approaches to capture them:

### Option 1: Capture and log manually

```powershell
Import-Module PoShLog

New-Logger | Add-SinkConsole | Add-SinkFile -Path 'C:\Logs\build.log' | Start-Logger

# Capture stdout and log it
$output = & dotnet build 2>&1
foreach ($line in $output) {
    if ($line -is [System.Management.Automation.ErrorRecord]) {
        Write-ErrorLog $line.ToString()
    } else {
        Write-InfoLog $line
    }
}

Close-Logger
```

### Option 2: Helper function for external commands

```powershell
function Invoke-Logged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Serilog.Events.LogEventLevel]$OutputLevel = 'Information',
        [Serilog.Events.LogEventLevel]$ErrorLevel = 'Error'
    )

    $output = & $ScriptBlock 2>&1
    foreach ($line in $output) {
        if ($line -is [System.Management.Automation.ErrorRecord]) {
            Write-ErrorLog $line.ToString()
        } else {
            Write-InformationLog $line.ToString()
        }
    }
}

# Usage:
Invoke-Logged { dotnet restore }
Invoke-Logged { dotnet build /p:Version=1.0.0 }
Invoke-Logged { dotnet test }
```

### Option 3: Use PowerShell transcript + Serilog

Combine PowerShell's built-in transcript with PoShLog for structured logging:

```powershell
Import-Module PoShLog

New-Logger | Add-SinkFile -Path 'C:\Logs\structured.log' | Start-Logger

# Start transcript for raw console capture
Start-Transcript -Path 'C:\Logs\raw-console.txt'

Write-InfoLog "Starting build process"
dotnet build  # captured by transcript (raw), not by Serilog

Write-InfoLog "Build complete"

Stop-Transcript
Close-Logger
```

## Capturing All Streams

To redirect PowerShell's verbose, warning, and debug streams into PoShLog:

```powershell
Import-Module PoShLog

New-Logger |
    Add-SinkConsole |
    Add-SinkFile -Path 'C:\Logs\allstreams.log' |
    Start-Logger

# Run a script that uses various streams and capture everything
$allOutput = & {
    Write-Verbose "Verbose message" -Verbose
    Write-Warning "Warning message"
    Write-Debug "Debug message" -Debug
    Write-Output "Normal output"
    Write-Error "Error message" 2>&1
} *>&1

foreach ($item in $allOutput) {
    switch ($item) {
        { $_ -is [System.Management.Automation.VerboseRecord] }     { Write-VerboseLog $_.Message }
        { $_ -is [System.Management.Automation.WarningRecord] }     { Write-WarningLog $_.Message }
        { $_ -is [System.Management.Automation.DebugRecord] }       { Write-DebugLog $_.Message }
        { $_ -is [System.Management.Automation.ErrorRecord] }       { Write-ErrorLog $_.Exception.Message -ErrorRecord $_ }
        default                                                      { Write-InfoLog $_.ToString() }
    }
}

Close-Logger
```

## Future: Automatic Capture (Planned)

We are planning a `Start-LogCapture` / `Stop-LogCapture` cmdlet pair that would automatically intercept all PowerShell streams and external command output, routing them to Serilog without manual intervention. Track progress in the GitHub issues.
