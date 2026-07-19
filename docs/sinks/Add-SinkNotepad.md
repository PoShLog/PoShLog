### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.Notepad](https://github.com/PoShLog/PoShLog.Sinks.Notepad) to be installed.

```ps1
Install-Module PoShLog.Sinks.Notepad
```

# Add-SinkNotepad `EXTENSION`

Writes log events into the Notepad application.

```ps1
Add-SinkNotepad
    -LoggerConfig <LoggerConfiguration>
    [-LevelSwitch <LoggingLevelSwitch>]
    [-OutputTemplate <string>]
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-NotepadProcessFinderFunc <Func[Process]>]
    [-SyncRoot <Object>]
    [<CommonParameters>]
```

```ps1
Add-SinkNotepad
    -LoggerConfig <LoggerConfiguration>
    -OutputTemplate <string>
    -FormatProvider <IFormatProvider>
    [<CommonParameters>]
```

```ps1
Add-SinkNotepad
    -LoggerConfig <LoggerConfiguration>
    -Formatter <ITextFormatter>
    [<CommonParameters>]
```

## Description

This cmdlet sinks log event messages into the most recently opened Notepad application.

## Examples

##### Example 1: Minimum setup needed to log into Notepad

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.Notepad

New-Logger |
    Add-SinkNotepad |
    Add-SinkConsole |
    Start-Logger

Close-Logger
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

##### `-LevelSwitch`

A switch allowing the pass-through minimum level to be changed at runtime.

|||
|-|-|
| Type: | Serilog.Core.LoggingLevelSwitch |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Formatter`

A formatter, such as JsonFormatter (see [`Get-JsonFormatter`](../cmdlets/Get-JsonFormatter.md)), to convert the log events into text.

|||
|-|-|
| Type: | Serilog.Formatting.ITextFormatter |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-OutputTemplate`

A message template describing the format used to write to the sink.

|||
|-|-|
| Type: | String |
| Position: | Named |
| Default value: | `'{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}'` |
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

##### `-RestrictedToMinimumLevel`

The minimum level for events passed through the sink.

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

##### `-NotepadProcessFinderFunc`

Func that finds the target `notepad.exe` process to send log messages to.

|||
|-|-|
| Type: | Nullable\<System.Diagnostics.Process\> |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-SyncRoot`

An object used to `lock` (sync) access to the Notepad output.

|||
|-|-|
| Type: | object |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
