### Dependencies

This cmdlet requires the extension module [PoShLog.Enrichers](https://github.com/PoShLog/PoShLog.Enrichers) to be installed.

```ps1
Install-Module PoShLog.Enrichers
```

# Add-EnrichWithEnvironment `EXTENSION`

Enriches events with information from the process environment.

```ps1
Add-EnrichWithEnvironment
    [-LoggerConfig] <LoggerConfiguration>
    [-UserName]
    [-MachineName]
    [<CommonParameters>]
```

## Description

This cmdlet automatically adds the current `UserName` and/or `MachineName` into log event properties. View this property by adding it to a sink's `-OutputTemplate`, or by adding `{Properties:j}` to the `-OutputTemplate`. You can also view all properties in many cloud sinks (Seq, Exceptionless, ...).

## Examples

##### Example 1: Show user name in console

Note that `UserName` is added by default if no parameter is specified.

```ps1
New-Logger |
    Add-EnrichWithEnvironment |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {UserName} {Level:u3}] {Message:lj}{NewLine}{Exception}{ErrorRecord}' |
    Start-Logger
```

##### Example 2: Show machine name in console

```ps1
New-Logger |
    Add-EnrichWithEnvironment -MachineName |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {MachineName} {Level:u3}] {Message:lj}{NewLine}{Exception}{ErrorRecord}' |
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

##### `-UserName`

Adds the UserName property to log event messages.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-MachineName`

Adds the MachineName property to log event messages.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
