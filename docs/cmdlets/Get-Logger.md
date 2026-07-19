# Get-Logger

Gets the current logger stored in the static property `[Serilog.Log]::Logger`.

```ps1
Get-Logger
    [<CommonParameters>]
```

## Description

`Get-Logger` returns the currently configured global `Serilog.ILogger` instance. This is useful when you need to pass the active logger to another function or cmdlet, or inspect what's currently configured.

> Implemented as the compiled `GetLoggerCommand` cmdlet class (`src/dotnet/Cmdlets/Core/GetLoggerCommand.cs`).

## Examples

##### Example 1: Get the current logger

```ps1
$logger = Get-Logger
```
