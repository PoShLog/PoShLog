# Migrating from Write-Host, Write-Verbose and transcripts

Most scripts start with `Write-Host`, `Write-Verbose`, `Write-Warning` and maybe a `Start-Transcript`. That works on
the screen, but the result is text: nothing can filter by the server name, count failures per database or alert on a
duration. PoShLog keeps the screen output and adds structured events that go to a file or a log server.

## What changes

| Before | With PoShLog |
|---|---|
| `Write-Host "Copied $count files to $target"` | `Write-InfoLog 'Copied {Count} files to {Target}' -PropertyValues $count, $target` |
| `Write-Verbose "Reading $path"` | `Write-VerboseLog 'Reading {Path}' -PropertyValues $path` |
| `Write-Warning "Disk $drive is $percent % full"` | `Write-WarningLog 'Disk {Drive} is {Percent} % full' -PropertyValues $drive, $percent` |
| `Write-Error $_` in a `catch` | `Write-ErrorLog 'Backup failed' -ErrorRecord $_`, and keep `throw` if the script should stop |
| `Start-Transcript -Path log.txt` | `Add-SinkFile -Path 'log-.txt' -RollingInterval Day`, plus the transcript if you still want raw console text |

The message is a **template**, not an interpolated string. Use single quotes, so PowerShell does not expand
`$variables` into the text, and pass the values with `-PropertyValues`. The text on screen is the same, but each value
is also kept as a property: `Count` stays the number 42, and a log server can filter `Count > 40`.

## Step by step

1. Start a logger at the top of the script and close it at the end, in a `finally`, so the file is flushed even when
   the script fails:

   ```powershell
   Import-Module PoShLog

   New-Logger |
       Set-MinimumLevel -Value Verbose |
       Add-SinkPowerShell |
       Add-SinkFile -Path "$PSScriptRoot/logs/backup-.log" -RollingInterval Day |
       Start-Logger

   try {
       # the script
   }
   finally {
       Close-Logger
   }
   ```

   [`Add-SinkPowerShell`](../cmdlets/Add-SinkPowerShell.md) writes each level to the stream PowerShell would use, so
   `-Verbose`, `$VerbosePreference` and redirection keep working. Use [`Add-SinkConsole`](../cmdlets/Add-SinkConsole.md)
   instead for coloured, timestamped console lines.

2. Replace the `Write-*` calls. [`Convert-LogFunctions`](../cmdlets/Convert-LogFunctions.md) can propose the simple
   renames and shows what it skipped; review every change.

3. Turn interpolated strings into templates with `-PropertyValues`. Name the properties the way you want to search
   for them later (`{Server}`, `{Database}`, `{ElapsedMs}`).

4. Keep errors as errors. `Write-ErrorLog` records the failure but does not stop the script or add to `$Error`. Where
   the script relied on `Write-Error` or `-ErrorAction Stop`, log and then `throw`.

## Transcripts

`Start-Transcript` records everything the host shows, including the output of external programs. PoShLog records the
events you write. The two work together: the PowerShell sink's Warning, Error and Fatal events appear in a transcript,
and [Capturing console output](capturing-output.md) shows how to log the output of external commands as events.

## Next

- [Usage and message templates](../usage.md)
- [Scheduled script recipe](../recipes/scheduled-script.md), a complete script with a rolling file and an exit code
- [Log event levels](../log-event-levels.md)
