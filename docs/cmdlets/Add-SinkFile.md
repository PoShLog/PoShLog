# Add-SinkFile

Writes log events into a file.

```ps1
Add-SinkFile
    -LoggerConfig <LoggerConfiguration>
    -Path <string>
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-OutputTemplate <string>]
    [-FormatProvider <IFormatProvider>]
    [-FileSizeLimitBytes <long>]
    [-LevelSwitch <LoggingLevelSwitch>]
    [-Buffered]
    [-Shared]
    [-FlushToDiskInterval <timespan>]
    [-RollingInterval <RollingInterval>]
    [-RollOnFileSizeLimit]
    [-RetainedFileCountLimit <int>]
    [-Encoding <Encoding>]
    [-Hooks <FileLifecycleHooks>]
    [<CommonParameters>]
```

```ps1
Add-SinkFile
    -LoggerConfig <LoggerConfiguration>
    -Path <string>
    -Formatter <ITextFormatter>
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-OutputTemplate <string>]
    [-FileSizeLimitBytes <long>]
    [-LevelSwitch <LoggingLevelSwitch>]
    [-Buffered]
    [-Shared]
    [-FlushToDiskInterval <timespan>]
    [-RollingInterval <RollingInterval>]
    [-RollOnFileSizeLimit]
    [-RetainedFileCountLimit <int>]
    [-Encoding <Encoding>]
    [-Hooks <FileLifecycleHooks>]
    [<CommonParameters>]
```

## Description

Allows you to log event messages into a file.

> Implemented as the compiled `AddSinkFileCommand` cmdlet class (`src/dotnet/Cmdlets/Sinks/AddSinkFileCommand.cs`), calling `Serilog.Sinks.File` (v6.0.0).

## Examples

##### Example 1: Minimum setup needed to log into a file

All log messages will be written into `C:\Logs\log.txt`.

```ps1
New-Logger |
    Add-SinkFile -Path 'C:\Logs\log.txt' |
    Start-Logger
```

##### Example 2: Logging into a new file every day

A new log file is created every day. The filename format depends on `-RollingInterval`; here `Day` produces e.g. `C:\Logs\log-20200329.txt`.

```ps1
New-Logger |
    Add-SinkFile -Path 'C:\Logs\log-.txt' -RollingInterval Day |
    Start-Logger
```

##### Example 3: Formatting file output

```ps1
New-Logger |
    Add-SinkFile -Path 'C:\Logs\log-.txt' -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' |
    Start-Logger
```

##### Example 4: JSON formatting

```ps1
New-Logger |
    Set-MinimumLevel -Value Verbose -ToPreference |
    Add-SinkFile -Path 'C:\test.log' -Formatter (Get-JsonFormatter) |
    Add-SinkPowerShell |
    Start-Logger
```

Example output:

```json
{"Timestamp":"2020-06-26T21:14:14.5715884+02:00","Level":"Fatal","MessageTemplate":"Test fatal message"}
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

##### `-Path`

Path to the file.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Formatter`

A formatter, such as JsonFormatter (see [`Get-JsonFormatter`](Get-JsonFormatter.md)), to convert log events into text for the file. If control of regular text formatting is required, use the Default parameter set.

|||
|-|-|
| Type: | Serilog.Formatting.ITextFormatter |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
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

##### `-FileSizeLimitBytes`

The approximate maximum size, in bytes, to which a log file will be allowed to grow. Pass null for unrestricted growth. Default is 1 GB.

|||
|-|-|
| Type: | Nullable[long] |
| Position: | Named |
| Default value: | 1073741824 |
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

##### `-Buffered`

Indicates if flushing to the output file can be buffered. Default is false.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Shared`

Allow the log file to be shared by multiple processes. Default is false.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-FlushToDiskInterval`

If provided, a full disk flush will be performed periodically at the specified interval.

|||
|-|-|
| Type: | Nullable[timespan] |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-RollingInterval`

The interval at which logging will roll over to a new file.

Following values are allowed:

* Infinite
* Year
* Month
* Day
* Hour
* Minute

|||
|-|-|
| Type: | Serilog.RollingInterval |
| Position: | Named |
| Default value: | Infinite |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-RollOnFileSizeLimit`

If true, a new file will be created when the size limit is reached, appending `_NNN` to filenames.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-RetainedFileCountLimit`

The maximum number of log files retained, including the current one. Pass null for unlimited retention. Default is 31.

|||
|-|-|
| Type: | Nullable[int] |
| Position: | Named |
| Default value: | 31 |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Encoding`

Character encoding used to write the text file. Default is UTF-8 without BOM.

|||
|-|-|
| Type: | System.Text.Encoding |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Hooks`

Optionally enables hooking into log file lifecycle events.

|||
|-|-|
| Type: | Serilog.Sinks.File.FileLifecycleHooks |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
