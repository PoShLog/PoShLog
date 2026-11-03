# Get-CurrentLogFiles

Returns the paths of the files the logger currently writes to.

```ps1
Get-CurrentLogFiles
    [-Logger <ILogger>]
    [<CommonParameters>]
```

## Description

With a rolling file (`Add-SinkFile -RollingInterval Day`) the file name gets a date, so the script does not know it in
advance. `Get-CurrentLogFiles` returns the full path of every file sink's current file, for example to attach the log
to an e-mail or upload it as a CI artifact. It returns nothing when the logger has no file sink or is closed.

> Implemented as the compiled `GetCurrentLogFilesCommand` cmdlet class (`src/dotnet/Cmdlets/Helpers/GetCurrentLogFilesCommand.cs`).

## Examples

##### Example 1: The file of a daily rolling log

```ps1
New-Logger | Add-SinkFile -Path 'C:\Logs\app-.log' -RollingInterval Day | Start-Logger
Write-InfoLog 'Hello'

Get-CurrentLogFiles
```

Example output:

```
C:\Logs\app-20261103.log
```

##### Example 2: Copy the log before closing it

```ps1
$files = Get-CurrentLogFiles
Close-Logger
Copy-Item $files -Destination $env:RUNNER_TEMP
```

## Parameters

##### `-Logger`

Instance of `Serilog.ILogger`. By default the static `[Serilog.Log]::Logger` is used.

|||
|-|-|
| Type: | Serilog.ILogger |
| Position: | Named |
| Default value: | `[Serilog.Log]::Logger` |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |

## Outputs

`System.String`, one full path per file.
