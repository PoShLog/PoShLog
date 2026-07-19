### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.Exceptionless](https://github.com/PoShLog/PoShLog.Sinks.Exceptionless) to be installed.

```ps1
Install-Module PoShLog.Sinks.Exceptionless
```

# Add-SinkExceptionless `EXTENSION`

Writes log events into [Exceptionless.com](https://exceptionless.com).

```ps1
Add-SinkExceptionless
    [-LoggerConfig] <LoggerConfiguration>
    [-ApiKey] <string>
    [[-ServerUrl] <string>]
    [[-AdditionalOperation] <Func[EventBuilder,EventBuilder]>]
    [[-IncludeProperties] <bool>]
    [[-RestrictedToMinimumLevel] <LogEventLevel>]
    [<CommonParameters>]
```

## Description

Use this cmdlet if you want your log event messages to appear in the cloud at [Exceptionless.com](https://exceptionless.com).

## Examples

##### Example 1: Minimum setup needed to log into Exceptionless

```ps1
New-Logger |
    Add-SinkExceptionless -ApiKey 'YOUR_API_KEY' |
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

##### `-ServerUrl`

Optional URL of the server events will be sent to.

|||
|-|-|
| Type: | String |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-AdditionalOperation`

Any additional operation to run against the built exceptions.

|||
|-|-|
| Type: | System.Func``2[Exceptionless.EventBuilder, Exceptionless.EventBuilder] |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-IncludeProperties`

If false, suppresses sending the Serilog properties to Exceptionless.

|||
|-|-|
| Type: | bool |
| Position: | Named |
| Default value: | True |
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
