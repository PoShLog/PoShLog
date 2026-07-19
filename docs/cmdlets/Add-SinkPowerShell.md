# Add-SinkPowerShell

Writes log events to the PowerShell console host.

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
