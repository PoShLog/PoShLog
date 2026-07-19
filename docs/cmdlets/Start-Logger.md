# Start-Logger

Creates a new instance of the logger that writes to configured sinks.

```ps1
Start-Logger
    -LoggerConfig <LoggerConfiguration>
    [<CommonParameters>]
```

```ps1
Start-Logger
    [-MinimumLevel <LogEventLevel>]
    [-Console]
    [-PowerShell]
    [-FilePath <string>]
    [-FileRollingInterval <RollingInterval>]
    [-SetAsDefault]
    [-PassThru]
    [<CommonParameters>]
```

## Description

Starts logging. This cmdlet is crucial for leveraging all Serilog logger functionality. Without it, `Write-*Log` cmdlets won't produce any output.

> Implemented as the compiled `StartLoggerCommand` cmdlet class (`src/dotnet/Cmdlets/Core/StartLoggerCommand.cs`).

## Examples

##### Example 1: Setup logger that logs into `'C:\Logs\test.log'` and console host — short version

```ps1
Start-Logger -FilePath 'C:\Logs\test.log' -Console
```

##### Example 2: Setup logger that logs into `'C:\Logs\test.log'` and console host using fluent API

```ps1
New-Logger |
    Add-SinkFile -Path 'C:\Logs\test.log' |
    Add-SinkConsole |
    Start-Logger
```

##### Example 3: Setup logger with more options specified

```ps1
New-Logger |
    Add-SinkFile -Path 'C:\Logs\test-.txt' -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' |
    Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose |
    Start-Logger
```

##### Example 4: Setup logger that logs into PowerShell only — short version

Note that if you don't specify any sink (`-Console`, `-PowerShell` or `-FilePath 'C:\Log\...'`), a PowerShell sink is created by default.

```ps1
Start-Logger
```

## Parameters

##### `-LoggerConfig`

Instance of LoggerConfiguration that is already set up.

|||
|-|-|
| Type: | LoggerConfiguration |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |

##### `-MinimumLevel`

Sets current minimum level, below which no events should be generated.

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
| Default value: | Information |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Console`

Sets up console sink. All event messages will be written to console host. Shortcut for `Add-SinkConsole`.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-PowerShell`

Sets up PowerShell sink. All event messages will be written to PowerShell streams. Shortcut for `Add-SinkPowerShell`.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-FilePath`

Sets up File sink at given path. All messages will be written to the given file path. Shortcut for `Add-SinkFile`.

|||
|-|-|
| Type: | String |
| Position: | Named |
| Default value: |  |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-FileRollingInterval`

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
| Type: | RollingInterval |
| Position: | Named |
| Default value: | Infinite |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-PassThru`

Outputs the created instance of `Serilog.Logger` into the pipeline. Useful when you want to create more loggers.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-SetAsDefault`

Assigns the created and output logger into the static property `[Serilog.Log]::Logger` for global use. Works only together with `-PassThru`.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
