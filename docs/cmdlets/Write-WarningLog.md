# Write-WarningLog

Writes a `Warning` log message.

```ps1
Write-WarningLog
    [-MessageTemplate] <string>
    [-Logger <ILogger>]
    [-Exception <Exception>]
    [-PropertyValues <Object[]>]
    [-PassThru]
    [<CommonParameters>]
```

```ps1
Write-WarningLog
    [[-MessageTemplate] <string>]
    -ErrorRecord <ErrorRecord>
    [-Logger <ILogger>]
    [-Exception <Exception>]
    [-PropertyValues <Object[]>]
    [-PassThru]
    [<CommonParameters>]
```

## Description

Write a log event with the `Warning` level.

> Implemented as the compiled `WriteWarningLogCommand` cmdlet class (`src/dotnet/Cmdlets/Write/WriteWarningLogCommand.cs`), sharing the common `WriteLogCmdletBase`.

## Examples

##### Example 1: Write simple log message

```ps1
Write-WarningLog 'My Log Message'
```

Or use pipeline input:

```ps1
'My Log Message' | Write-WarningLog
```

##### Example 2: Write log message with properties

```ps1
Write-WarningLog 'My {Number} Log Message.' -PropertyValues 'First'
# Alternatively
Write-WarningLog -MessageTemplate 'My {Number} Log Message.' -PropertyValues 'First'
```

##### Example 3: Write log message with ErrorRecord

```ps1
try {
    throw 'error'
}
catch {
    Write-WarningLog -ErrorRecord $_
}
```

Or specify your own message:

```ps1
try {
    throw 'error'
}
catch {
    Write-WarningLog 'Error occurred while doing some business! {SomeNumber}' -ErrorRecord $_ -PropertyValues 123
}
```

##### Example 4: Write log message with Exception

```ps1
try {
    throw 'error'
}
catch {
    Write-WarningLog 'Error occurred while doing some business!' -Exception $_.Exception
}
```

##### Example 5: Using `-PassThru`

```ps1
$message = Write-WarningLog 'Some {What} that will be passed thru' -PropertyValues 'message' -PassThru
$message # Contains string: "Some message that will be passed thru"
```

## Parameters

##### `-MessageTemplate`

Message template describing the event.

|||
|-|-|
| Type: | string |
| Position: | 0 |
| Default value: |  |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |

##### `-Logger`

Instance of `Serilog.ILogger`. By default the static property `[Serilog.Log]::Logger` is used. Use `$logger = Start-Logger -PassThru` to get an instance of the logger.

|||
|-|-|
| Type: | Serilog.ILogger |
| Position: | Named |
| Default value: | `[Serilog.Log]::Logger` |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Exception`

Exception related to the event.

|||
|-|-|
| Type: | System.Exception |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-ErrorRecord`

ErrorRecord related to the event.

|||
|-|-|
| Type: | System.Management.Automation.ErrorRecord |
| Position: | Named |
| Aliases: | ER |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-PropertyValues`

Objects positionally formatted into the message template.

|||
|-|-|
| Type: | object[] |
| Position: | Named |
| Default value: | $null |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-PassThru`

If set, outputs `MessageTemplate` populated with `PropertyValues` into the pipeline.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
