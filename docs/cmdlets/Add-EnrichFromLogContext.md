# Add-EnrichFromLogContext

Enriches log events with properties pushed onto the ambient `LogContext`.

```ps1
Add-EnrichFromLogContext
    -LoggerConfig <LoggerConfiguration>
    [<CommonParameters>]
```

## Description

Enriches log events with properties from Serilog's ambient `LogContext`. Combine this with [`Push-LogContextProperty`](Push-LogContextProperty.md) to attach contextual properties to all log events written within a given scope.

> Implemented as the compiled `AddEnrichFromLogContextCommand` cmdlet class (`src/dotnet/Cmdlets/Enrichers/AddEnrichFromLogContextCommand.cs`).

## Examples

##### Example 1: Enable LogContext enrichment

```ps1
New-Logger |
    Add-EnrichFromLogContext |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj} {Properties:j}{NewLine}{Exception}' |
    Start-Logger

Push-LogContextProperty -Name RunId -Value 42 -ScriptBlock {
    Write-InfoLog 'Carries RunId'
}
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
