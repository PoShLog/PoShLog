# Close-Logger

Resets Logger to the default and disposes the original if possible.

```ps1
Close-Logger
    [<CommonParameters>]
```

## Description

Use this cmdlet at the end of every logging session to properly dispose all resources.

> Implemented as the compiled `CloseLoggerCommand` cmdlet class (`src/dotnet/Cmdlets/Core/CloseLoggerCommand.cs`).

## Examples

##### Example 1: Close logger

```ps1
Close-Logger
```
