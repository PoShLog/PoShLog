# Get-CompactFormatter

Returns a formatter that writes the Compact Log Event Format (CLEF).

```ps1
Get-CompactFormatter
    [-Rendered]
    [<CommonParameters>]
```

## Description

[CLEF](https://clef-json.org/) is newline-delimited JSON: one object per event, with the reserved fields `@t` (timestamp, UTC), `@mt` (message template), `@m` (rendered message), `@l` (level, omitted for `Information`), `@x` (exception), `@r` (renderings of formatted tokens), `@i` (event id), `@tr`/`@sp` (trace and span ids) and the event's properties. Seq, Compact Log Viewer, `clef-tool` and many log shippers read it directly.

Pass the formatter to the `-Formatter` parameter of [`Add-SinkFile`](Add-SinkFile.md) or [`Add-SinkConsole`](Add-SinkConsole.md). The output template of those sinks is not used when a formatter is given.

- By default the event keeps its message template (`@mt`), which keeps log files small and lets tools group events by template.
- With `-Rendered` the event carries the rendered message (`@m`) and an event id (`@i`, a hash of the template) instead.

The output is the same as `CompactJsonFormatter` and `RenderedCompactJsonFormatter` from `Serilog.Formatting.Compact`. PoShLog ships its own copy, so that package is not loaded next to extensions that bring an older version of it ([ADR 0007](../decisions/0007-clef-formatter-in-core.md)). The returned type is `PoShLog.Core.Formatting.CompactJsonFormatter`.

> Implemented as the compiled `GetCompactFormatterCommand` cmdlet class (`src/dotnet/Cmdlets/Formatters/GetCompactFormatterCommand.cs`).

## Examples

##### Example 1: Write a CLEF log file

```ps1
New-Logger |
    Set-MinimumLevel -Value Verbose |
    Add-SinkFile -Path 'C:\Logs\app.clef' -Formatter (Get-CompactFormatter) |
    Start-Logger

Write-InfoLog 'Service {Name} is {@State}' -PropertyValues 'EventLog', ([pscustomobject]@{ Status = 'Running' })
Write-WarningLog 'Disk {Drive} is {Percent:0.0} % full' -PropertyValues 'C:', 91.25
Close-Logger
```

Example output:

```json
{"@t":"2026-11-03T09:24:44.9554810Z","@mt":"Service {Name} is {@State}","Name":"EventLog","State":{"Status":"Running"}}
{"@t":"2026-11-03T09:24:44.9685558Z","@mt":"Disk {Drive} is {Percent:0.0} % full","@r":["91.3"],"@l":"Warning","Drive":"C:","Percent":91.25}
```

##### Example 2: Rendered CLEF on the console, for a container log collector

```ps1
New-Logger |
    Add-SinkConsole -Formatter (Get-CompactFormatter -Rendered) |
    Start-Logger
```

##### Example 3: Read a CLEF file back

```ps1
Get-Content 'C:\Logs\app.clef' | ConvertFrom-Json | Where-Object '@l' -eq 'Warning'
```

## Parameters

##### `-Rendered`

Write the rendered message (`@m`) and an event id (`@i`) instead of the message template (`@mt`) and renderings (`@r`).

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

## Outputs

`PoShLog.Core.Formatting.CompactJsonFormatter`, a `Serilog.Formatting.ITextFormatter`.
