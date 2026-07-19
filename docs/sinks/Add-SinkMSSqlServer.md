### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.MSSqlServer](https://github.com/PoShLog/PoShLog.Sinks.MSSqlServer) to be installed.

```ps1
Install-Module PoShLog.Sinks.MSSqlServer
```

# Add-SinkMSSqlServer `EXTENSION`

Writes log events into a Microsoft SQL Server database.

```ps1
Add-SinkMSSqlServer
    -LoggerConfig <LoggerConfiguration>
    -ConnectionString <string>
    -TableName <string>
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-AutoCreateSqlTable]
    [-BatchPostingLimit <int>]
    [-Period <timespan>]
    [<CommonParameters>]
```

## Description

Use this cmdlet to write log event messages into a Microsoft SQL Server database via [Serilog.Sinks.MSSqlServer](https://www.nuget.org/packages/Serilog.Sinks.MSSqlServer/).

## Examples

##### Example 1: Minimum setup needed to log into MSSQL Server

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.MSSqlServer

New-Logger |
    Add-SinkMSSqlServer -ConnectionString 'Server=.;Database=Logs;Trusted_Connection=True;' -TableName 'Logs' -AutoCreateSqlTable |
    Start-Logger

Write-InfoLog 'My message in MSSQL Server'

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

##### `-ConnectionString`

Connection string (or connection string name from configuration) to the target database.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-TableName`

Name of the table to write log events to.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-RestrictedToMinimumLevel`

The minimum level for events passed through the sink.

|||
|-|-|
| Type: | LogEventLevel |
| Position: | Named |
| Default value: | Verbose |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-AutoCreateSqlTable`

If set, automatically creates the target table if it doesn't already exist.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-BatchPostingLimit`

The maximum number of events to include in a single batch.

|||
|-|-|
| Type: | int |
| Position: | Named |
| Default value: | 50 |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Period`

The time to wait between checking for event batches.

|||
|-|-|
| Type: | timespan |
| Position: | Named |
| Default value: | 00:00:05 |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

> This page documents the extension module's public surface at a high level; consult the [PoShLog.Sinks.MSSqlServer](https://github.com/PoShLog/PoShLog.Sinks.MSSqlServer) repository for the authoritative and most up-to-date parameter reference.
