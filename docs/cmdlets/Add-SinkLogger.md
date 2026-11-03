# Add-SinkLogger

Writes log events to another logger, a sub-logger, where they are processed further.

```ps1
Add-SinkLogger
    -LoggerConfig <LoggerConfiguration>
    -Logger <ILogger>
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [<CommonParameters>]
```

## Description

A sub-logger gets every event the parent logger lets through, after the parent's filters and enrichers. It can then
send them to its own sinks with its own output templates. Use it when one destination should get only part of the
events, for example errors in a separate file, while the parent logs everything.

A sub-logger cannot log at a more verbose level than the parent. It can be less verbose, through
`-RestrictedToMinimumLevel` or its own minimum level.

The sub-logger is not closed by `Close-Logger`. Dispose it yourself when the parent is closed.

> Implemented as the compiled `AddSinkLoggerCommand` cmdlet class (`src/dotnet/Cmdlets/Sinks/AddSinkLoggerCommand.cs`).

## Examples

##### Example 1: Errors in their own file

```ps1
$errors = New-Logger |
    Add-SinkFile -Path 'C:\Logs\errors.log' -OutputTemplate '{Level:u3} {Message:lj}{NewLine}' |
    Start-Logger -PassThru

New-Logger |
    Set-MinimumLevel -Value Verbose |
    Add-SinkFile -Path 'C:\Logs\all.log' -OutputTemplate '{Level:u3} {Message:lj}{NewLine}' |
    Add-SinkLogger -Logger $errors -RestrictedToMinimumLevel Error |
    Start-Logger

Write-InfoLog 'Backup started'
Write-ErrorLog 'Backup of {Database} failed' -PropertyValues 'Sales'

Close-Logger
$errors.Dispose()
```

`all.log` has both events; `errors.log` has only the error:

```
ERR Backup of Sales failed
```

## Parameters

##### `-LoggerConfig`

Instance of `LoggerConfiguration`, usually from [`New-Logger`](New-Logger.md).

|||
|-|-|
| Type: | Serilog.LoggerConfiguration |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |

##### `-Logger`

The sub-logger, for example from `Start-Logger -PassThru`.

|||
|-|-|
| Type: | Serilog.ILogger |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-RestrictedToMinimumLevel`

The minimum level of the events passed to the sub-logger.

|||
|-|-|
| Type: | Serilog.Events.LogEventLevel |
| Position: | Named |
| Default value: | Verbose |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

## Outputs

`Serilog.LoggerConfiguration`, so the pipeline can continue.
