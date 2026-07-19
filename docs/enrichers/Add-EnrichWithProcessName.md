### Dependencies

This cmdlet requires the extension module [PoShLog.Enrichers](https://github.com/PoShLog/PoShLog.Enrichers) to be installed.

```ps1
Install-Module PoShLog.Enrichers
```

# Add-EnrichWithProcessName `EXTENSION`

Enriches log events with the current process name.

```ps1
Add-EnrichWithProcessName
    [-LoggerConfig] <LoggerConfiguration>
    [<CommonParameters>]
```

## Description

This cmdlet automatically adds the current process name (`ProcessName`) into log event properties. View this property by adding it to a sink's `-OutputTemplate`, or by adding `{Properties:j}` to the `-OutputTemplate`. You can also view all properties in many cloud sinks (Seq, Exceptionless, ...).

## Examples

##### Example 1: Show process name in console

```ps1
New-Logger |
    Add-EnrichWithProcessName |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {ProcessName} {Level:u3}] {Message:lj}{NewLine}{Exception}{ErrorRecord}' |
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
