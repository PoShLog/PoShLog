# Add-EnrichWithProperty

Enriches log events with a custom property. For example, script name.

```ps1
Add-EnrichWithProperty
    -LoggerConfig <LoggerConfiguration>
    -Name <string>
    -Value <string>
    [-DestructureObjects <bool>]
    [<CommonParameters>]
```

## Description

Adds a custom, statically-named property with a fixed value to every log event produced by the logger.

> Implemented as the compiled `AddEnrichWithPropertyCommand` cmdlet class (`src/dotnet/Cmdlets/Enrichers/AddEnrichWithPropertyCommand.cs`).

## Examples

##### Example 1: Tag all log events with the current script name

```ps1
New-Logger |
    Add-EnrichWithProperty -Name 'ScriptName' -Value $MyInvocation.MyCommand.Name |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj} {ScriptName}{NewLine}{Exception}' |
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

##### `-Name`

Name of the property to add.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Value`

Value of the property to add.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-DestructureObjects`

If true, the value will be destructured (captured as structured data) rather than serialized with `ToString()`.

|||
|-|-|
| Type: | bool |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
