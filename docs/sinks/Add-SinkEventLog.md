### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.EventLog](https://github.com/PoShLog/PoShLog.Sinks.EventLog) to be installed.

```ps1
Install-Module PoShLog.Sinks.EventLog
```

# Add-SinkEventLog `EXTENSION`

Writes log events to Windows Event Log.

```ps1
Add-SinkEventLog
    [-LoggerConfig] <LoggerConfiguration>
    [-Source] <string>
    [[-LogName] <string>]
    [[-MachineName] <string>]
    [[-ManageEventSource] <string>]
    [[-OutputTemplate] <string>]
    [[-FormatProvider] <IFormatProvider>]
    [[-RestrictedToMinimumLevel] <LogEventLevel>]
    [[-EventIdProvider] <IEventIdProvider>]
    [<CommonParameters>]
```

## Description

This cmdlet sinks log event messages into the Windows Event Log. **Note that before first use you should run the following script as administrator to register your `-Source`. Notice the `-ManageEventSource` parameter.**

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.EventLog

New-Logger |
    Add-SinkEventLog -Source 'Sample Script' -ManageEventSource $true |
    Start-Logger

Close-Logger
```

## Examples

##### Example 1: Minimum setup needed to log into Windows Event Log

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.EventLog

New-Logger |
    Add-SinkEventLog -Source 'Sample Script' |
    Start-Logger

Write-InfoLog 'My message in windows event log'
Write-ErrorLog 'My error message in windows event log'

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

##### `-Source`

The source name by which the application is registered on the local computer.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-LogName`

The name of the log the source's entries are written to. Possible values include Application, System, or a custom event log.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-MachineName`

The name of the machine hosting the event log written to. The local machine by default.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | `'.'` |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-ManageEventSource`

If true, check/create event source as required. Defaults to false — do not allow the sink to manage event source creation.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-OutputTemplate`

A message template describing the format used to write to the sink.

|||
|-|-|
| Type: | String |
| Position: | Named |
| Default value: | `'{Message}{NewLine}{Exception}{ErrorRecord}'` |
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

##### `-EventIdProvider`

Supplies event ids for emitted log events.

|||
|-|-|
| Type: | Serilog.Sinks.EventLog.IEventIdProvider |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
