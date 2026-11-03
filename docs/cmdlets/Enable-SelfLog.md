# Enable-SelfLog

Turns on Serilog's SelfLog, which reports PoShLog's and the sinks' own problems.

```ps1
Enable-SelfLog
    [-MessageFunc <Action[String]>]
    [<CommonParameters>]
```

## Description

Logging never throws into your script: when a sink cannot write (a server is down, a file is locked) or a message
template is invalid, the event is dropped quietly. SelfLog is where those problems are reported. Turn it on when
events go missing.

By default each message is written to the standard error stream (`Console.Error`), because a SelfLog message can come
at any time, also from a background thread after the command that caused it has finished. Pass `-MessageFunc` to
collect the messages yourself. Turn it off with [`Disable-SelfLog`](Disable-SelfLog.md).

> Implemented as the compiled `EnableSelfLogCommand` cmdlet class (`src/dotnet/Cmdlets/Debugging/EnableSelfLogCommand.cs`).

## Examples

##### Example 1: Why is a message missing?

```ps1
Enable-SelfLog
New-Logger | Add-SinkConsole | Start-Logger
Write-InfoLog 'Bad template {Name' -PropertyValues 'x'
Close-Logger
```

Example output on standard error:

```
2026-11-03T17:16:18.3666983Z Parameters provided for message template with no properties: Bad template {Name
```

##### Example 2: Collect the messages, for example in a test

```ps1
$messages = [System.Collections.Generic.List[string]]::new()
Enable-SelfLog -MessageFunc { param($message) $messages.Add($message) }.GetNewClosure()

# ... log ...

Disable-SelfLog
$messages
```

## Parameters

##### `-MessageFunc`

A script block or delegate that gets each message as a string. It can run on a background thread, so keep it short
and do not write to PowerShell streams from it.

|||
|-|-|
| Type: | System.Action[String] |
| Position: | Named |
| Default value: | Writes to `Console.Error` |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

## Outputs

None.
