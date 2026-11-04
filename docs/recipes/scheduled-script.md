# Recipe: a scheduled script

A job that runs unattended from Task Scheduler or cron. It logs to the console and to a daily rolling file, always
flushes the log, and reports its result as an exit code that the scheduler shows.

Sample: [samples/scheduled-script/Invoke-NightlyCleanup.ps1](../../samples/scheduled-script/Invoke-NightlyCleanup.ps1).
It removes files older than a number of days.

## Install

The scheduler runs the job as another account (often `SYSTEM` or a service account), so install PoShLog for all users.
See [Compatibility and installation](../compatibility.md) for versions.

```powershell
# In an elevated PowerShell 7.6+ session (sudo pwsh on Linux and macOS).
Install-PSResource PoShLog -Prerelease -Scope AllUsers
```

## The script

```powershell
#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'PoShLog'; ModuleVersion = '3.0.0' }
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

$exitCode = 0
try {
    Write-InfoLog 'Removing files older than {Days} days from {Path}' -PropertyValues $OlderThanDays, $Path
    # ... the work ...
    Write-InfoLog 'Removed {FileCount} files ({Bytes} bytes)' -PropertyValues $files.Count, $bytes
}
catch {
    Write-FatalLog 'Cleanup of {Path} failed' -PropertyValues $Path -ErrorRecord $_
    $exitCode = 1
}
finally {
    Close-Logger
}
exit $exitCode
```

- `#Requires -Modules` stops the script with a clear message when PoShLog 3 is not installed for the account that runs
  it.
- `$ErrorActionPreference = 'Stop'` turns every error into one that `catch` sees. Without it, a failing command writes
  an error and the script carries on to exit code 0.
- `Close-Logger` in `finally` flushes the file. The script sets `$exitCode` and calls `exit` after the `finally` block,
  so the logger is always closed first.
- `-RollingInterval Day` starts a new file every day (`nightly-cleanup-20261103.log`), and `-RetainedFileCountLimit 14`
  deletes the oldest file beyond fourteen.
- `{Properties:j}` adds the properties that are not in the message, here `Job`, as JSON at the end of each line.

## Expected output

A run that succeeds writes this to the console and exits with 0:

```text
[02:00:00 INF] Removing files older than 30 days from D:\Exports
[02:00:00 INF] Removed 1 files (10 bytes)
```

The same events in `logs/nightly-cleanup-20261103.log`:

```text
2026-11-03 02:00:00.240 +01:00 [INF] Removing files older than 30 days from D:\Exports {"Job":"nightly-cleanup"}
2026-11-03 02:00:00.325 +01:00 [INF] Removed 1 files (10 bytes) {"Job":"nightly-cleanup"}
```

A run that fails logs the error with its exception and exits with 1:

```text
2026-11-03 02:00:00.380 +01:00 [FTL] Cleanup of D:\Exports failed {"Job":"nightly-cleanup"}
System.Management.Automation.ItemNotFoundException: Cannot find path 'D:\Exports' because it does not exist.
```

## Schedule it

### Windows Task Scheduler

```powershell
$action = New-ScheduledTaskAction -Execute 'C:\Program Files\PowerShell\7\pwsh.exe' `
    -Argument '-NoProfile -NonInteractive -File "C:\Jobs\Invoke-NightlyCleanup.ps1" -Path "D:\Exports"'
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -TaskName 'Nightly cleanup' -Action $action -Trigger $trigger -User 'SYSTEM' -RunLevel Highest
```

Use `-File`, not `-Command`. With `-File`, the task's **Last Run Result** shows the script's exit code (`0x1` for 1).
With `-Command`, it shows only whether the last command succeeded.

### cron (Linux, macOS)

```text
0 2 * * * /usr/bin/pwsh -NoProfile -NonInteractive -File /opt/jobs/Invoke-NightlyCleanup.ps1 -Path /srv/exports
```

cron mails the console output to the account's owner when mail is set up. Append `>/dev/null 2>&1` to rely on the log
file only. On macOS, `pwsh` is usually `/usr/local/bin/pwsh` (Intel) or `/opt/homebrew/bin/pwsh` (Homebrew on Apple
silicon).

## Missing events?

- **No log file at all.** The log directory is relative to the working directory, which is `C:\Windows\System32` for a
  scheduled task and the home directory for cron. Pass an absolute `-LogDirectory`, or build it from `$PSScriptRoot` as
  the sample does. Also check that the account can write there.
- **The last events are missing.** `Close-Logger` did not run. Keep it in `finally`, and do not call `exit` inside
  `try` before it.
- **The task "succeeds" but the job failed.** Errors that do not stop the script never reach `catch`. Set
  `$ErrorActionPreference = 'Stop'` or pass `-ErrorAction Stop`, and start the task with `-File`.
- **"The script cannot be run because the following modules … are missing".** PoShLog is installed for your account
  only. Install it with `-Scope AllUsers`, or for the account the task runs as.
- **Two runs overlap and one cannot open the file.** Task Scheduler's default does not start a second instance, but
  cron does. Add `-Shared` to `Add-SinkFile`, or use a lock file.
- **Still nothing.** Call `Enable-SelfLog` before `Start-Logger`. Serilog then writes its own errors, such as a denied
  file path, to the console.

## Verified

`build/Test-Recipes.ps1` runs the sample against the staged package, in a new `pwsh` process. It checks both exit codes,
the deleted and kept files, and the console and file output. Registering a task in Task Scheduler and a cron entry are
not part of the check.
