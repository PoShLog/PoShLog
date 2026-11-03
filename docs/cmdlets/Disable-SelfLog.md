# Disable-SelfLog

Turns off Serilog's SelfLog.

```ps1
Disable-SelfLog
    [<CommonParameters>]
```

## Description

Stops reporting PoShLog's and the sinks' own problems, which [`Enable-SelfLog`](Enable-SelfLog.md) turned on. SelfLog
is off when PoShLog is imported.

> Implemented as the compiled `DisableSelfLogCommand` cmdlet class (`src/dotnet/Cmdlets/Debugging/DisableSelfLogCommand.cs`).

## Examples

##### Example 1: Turn SelfLog off again

```ps1
Disable-SelfLog
```

## Outputs

None.
