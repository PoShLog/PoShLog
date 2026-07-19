# Set-Logger

Sets given logger as the static property `[Serilog.Log]::Logger` that is globally available.

```ps1
Set-Logger
    -Logger <ILogger>
    [<CommonParameters>]
```

## Description

`Set-Logger` assigns a logger instance as the global default logger. This is useful when you built a logger with `-PassThru` (see [`Start-Logger`](Start-Logger.md)) and want to set it as the global logger afterwards, without using `-SetAsDefault` at start time.

> Implemented as the compiled `SetLoggerCommand` cmdlet class (`src/dotnet/Cmdlets/Core/SetLoggerCommand.cs`).

## Examples

##### Example 1: Create a logger and set it as global afterwards

```ps1
$logger = New-Logger | Add-SinkConsole | Start-Logger -PassThru
$logger | Set-Logger
```

## Parameters

##### `-Logger`

Instance of `Serilog.ILogger` to set as the global logger.

|||
|-|-|
| Type: | Serilog.ILogger |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |
