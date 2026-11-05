# Add-SinkPowerShell

Writes log events to the PowerShell console host.
Windows PowerShell 5.1 has host-specific transcript behaviour. Explicitly render information-stream records with
`Write-ErrorLog 'message' 6>&1 | Out-Host` when a transcript must include them.
See [compatibility](../compatibility.md) for the tested Desktop limits.

```ps1
Add-SinkPowerShell
    [-LoggerConfig] <LoggerConfiguration>
    [[-RestrictedToMinimumLevel] <LogEventLevel>]
    [[-OutputTemplate] <string>]
    [[-LevelSwitch] <LoggingLevelSwitch>]
    [<CommonParameters>]
```

## Description

This cmdlet sinks log event messages into the PowerShell console host. It writes log messages into PowerShell [streams](https://devblogs.microsoft.com/scripting/understanding-streams-redirection-and-write-host-in-powershell/), which you can then [redirect](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_redirection) or suppress using [preference variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables). Keep in mind that preference variables "override" the chosen minimum log level set via [`Set-MinimumLevel`](Set-MinimumLevel.md). You can propagate the minimum log level into preference variables using the [`-ToPreference`](Set-MinimumLevel.md#-topreference) parameter.

Each level goes to the stream PowerShell itself would use:

| Level | Stream | Shown by default | In the transcript |
|-------|--------|------------------|-------------------|
| Verbose | Verbose (4) | when `$VerbosePreference` shows it | when shown |
| Debug | Debug (5) | when `$DebugPreference` shows it | when shown |
| Information | Information (6) | when `$InformationPreference` shows it | when shown |
| Warning | Warning (3) | yes | yes |
| Error, Fatal | Information (6), red, like `Write-Host` | yes | yes |

Error and Fatal events are always shown and recorded by `Start-Transcript`, like `Write-Host` output. They are not written as PowerShell errors, so logging an error never stops a script that runs with `$ErrorActionPreference = 'Stop'` and never adds to `$Error`. They can still be redirected (`6>`) or captured (`-InformationVariable`). To hide them, pass `-InformationAction SilentlyContinue` to `Write-ErrorLog`/`Write-FatalLog`: an explicit `-InformationAction` is respected (issue #45, [ADR 0008](../decisions/0008-powershell-sink-streams.md)). All records carry the source `PoShLog`.

**Hosts that assign a log level per stream.** Some hosts turn PowerShell streams into log levels; Azure Functions, for
example, records the information stream as Information and the error stream as Error
([Microsoft documentation](https://learn.microsoft.com/azure/azure-functions/functions-reference-powershell)). There,
Error and Fatal events from this sink are therefore expected at Information level. Where the level matters, add a sink that
sends it with the event, such as [OpenTelemetry](../sinks/Add-SinkOpenTelemetry.md), Seq or Splunk. This has not been
verified in a Functions host yet.

Use this sink rather than [`Add-SinkConsole`](Add-SinkConsole.md) when the output should end up in a transcript.

> Implemented as the compiled `AddSinkPowerShellCommand` cmdlet class (`src/dotnet/Cmdlets/Sinks/AddSinkPowerShellCommand.cs`). Stream routing is handled via a thread-static "current cmdlet" context (`src/dotnet/Utils/PSCmdletContext.cs`) so log messages emitted by a `Write-*Log` cmdlet are written to that same cmdlet's PowerShell streams.

## Examples

##### Example 1: Minimum setup needed to log into the PowerShell console

```ps1
New-Logger |
    Add-SinkPowerShell |
    Start-Logger
```

##### Example 2: Restricting log levels

```ps1
New-Logger |
    Set-MinimumLevel -Value Debug |
    Add-SinkFile -Path 'log.txt' |
    Add-SinkPowerShell -RestrictedToMinimumLevel Information |
    Start-Logger
```

##### Example 3: Formatting PowerShell output

```ps1
New-Logger |
    Add-SinkPowerShell -OutputTemplate '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{Properties:j}{NewLine}{Exception}' |
    Start-Logger
```

## Parameters

##### `-LoggerConfig`

Instance of LoggerConfiguration.

|||
|-|-|
| Type: | LoggerConfiguration |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |

##### `-RestrictedToMinimumLevel`

The minimum level for events passed through the sink. Ignored when LevelSwitch is specified.

Following values are allowed:

* Verbose
* Debug
* Information
* Warning
* Error
* Fatal

|||
|-|-|
| Type: | LogEventLevel |
| Position: | Named |
| Default value: | Verbose |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-OutputTemplate`

A message template describing the format used to write to the sink.

|||
|-|-|
| Type: | String |
| Position: | Named |
| Default value: | `'[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}'` |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-LevelSwitch`

A switch allowing the pass-through minimum level to be changed at runtime.

|||
|-|-|
| Type: | Serilog.Core.LoggingLevelSwitch |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
