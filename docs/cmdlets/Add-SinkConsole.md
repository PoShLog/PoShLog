# Add-SinkConsole

Writes log events to console host.

```ps1
Add-SinkConsole
    [-LoggerConfig] <LoggerConfiguration>
    [[-RestrictedToMinimumLevel] <LogEventLevel>]
    [[-OutputTemplate] <string>]
    [[-FormatProvider] <IFormatProvider>]
    [[-LevelSwitch] <LoggingLevelSwitch>]
    [[-StandardErrorFromLevel] <LogEventLevel>]
    [[-Theme] <ConsoleTheme>]
    [<CommonParameters>]
```

## Description

Use this cmdlet if you want your log event messages to appear in the console host. **Keep in mind that the Console sink writes to `Success` *(1, stdout)* and `Error` *(2, stderr)* streams only, and `Error` is used only when `-StandardErrorFromLevel` is present.** If you want to write log messages into PowerShell streams, use [`Add-SinkPowerShell`](Add-SinkPowerShell.md) instead.

> Implemented as the compiled `AddSinkConsoleCommand` cmdlet class (`src/dotnet/Cmdlets/Sinks/AddSinkConsoleCommand.cs`), calling `Serilog.Sinks.Console` (v6.0.0).

## Examples

##### Example 1: Minimum setup needed to log into console

```ps1
New-Logger |
    Add-SinkConsole |
    Start-Logger
```

##### Example 2: Restricting log levels

Minimum log level is set to `Debug`, but the console sink is restricted to `Information` with `-RestrictedToMinimumLevel`. Messages from `Debug` to `Fatal` will be logged into the File sink, but only levels from `Information` to `Fatal` will appear in console.

```ps1
New-Logger |
    Set-MinimumLevel -Value Debug |
    Add-SinkFile -Path 'log.txt' |
    Add-SinkConsole -RestrictedToMinimumLevel Information |
    Start-Logger
```

##### Example 3: Formatting console output

Here `-OutputTemplate` is altered to add `{Properties:j}`, showing all event property values that don't otherwise appear in the output.

```ps1
New-Logger |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{Properties:j}{NewLine}{Exception}' |
    Start-Logger
```

![console sink format](../images/poshlog_example_addsinkconsole_format.png)

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

##### `-FormatProvider`

Supplies culture-specific formatting information, or null.

|||
|-|-|
| Type: | System.IFormatProvider |
| Position: | Named |
| Default value: | $null |
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

##### `-StandardErrorFromLevel`

Specifies the level at which events will be written to standard error.

|||
|-|-|
| Type: | Nullable[Serilog.Events.LogEventLevel] |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Theme`

The theme to apply to the styled output. If not specified, uses `Serilog.Sinks.SystemConsole.Themes.SystemConsoleTheme.Literate`.

|||
|-|-|
| Type: | Serilog.Sinks.SystemConsole.Themes.ConsoleTheme |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
