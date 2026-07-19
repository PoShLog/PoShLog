# Get-JsonFormatter

Returns a new instance of `Serilog.Formatting.Json.JsonFormatter`.

```ps1
Get-JsonFormatter
    [<CommonParameters>]
```

## Description

Use this cmdlet to obtain a JSON formatter that can be passed to the `-Formatter` parameter of sinks that support it (e.g. [`Add-SinkFile`](Add-SinkFile.md)).

> Implemented as the compiled `GetJsonFormatterCommand` cmdlet class (`src/dotnet/Cmdlets/Formatters/GetJsonFormatterCommand.cs`).

## Examples

##### Example 1: Write JSON-formatted log lines to a file

```ps1
New-Logger |
    Add-SinkFile -Path 'C:\test.log' -Formatter (Get-JsonFormatter) |
    Start-Logger

Write-FatalLog 'Test fatal message'
```

Example output:

```json
{"Timestamp":"2020-06-26T21:14:14.5715884+02:00","Level":"Fatal","MessageTemplate":"Test fatal message"}
```
