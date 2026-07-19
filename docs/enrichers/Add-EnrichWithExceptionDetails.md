### Dependencies

This cmdlet requires the extension module [PoShLog.Enrichers](https://github.com/PoShLog/PoShLog.Enrichers) to be installed.

```ps1
Install-Module PoShLog.Enrichers
```

# Add-EnrichWithExceptionDetails `EXTENSION`

Automatically adds additional structured properties from exceptions into log events.

```ps1
Add-EnrichWithExceptionDetails
    [-LoggerConfig] <LoggerConfiguration>
    [<CommonParameters>]
```

## Description

This cmdlet automatically adds properties from exceptions into log events. View these properties by adding `{Properties:j}` to a sink's `-OutputTemplate`. You can also view all properties in many cloud sinks (Seq, Exceptionless, ...).

## Examples

##### Example 1: Show exception details in console

```ps1
New-Logger |
    Add-EnrichWithExceptionDetails |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}{ErrorRecord}{Properties:j}' |
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
