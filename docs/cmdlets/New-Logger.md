# New-Logger

Creates instance of Serilog logger configuration.

```ps1
New-Logger
    [-ConfigurationPath <string>]
    [<CommonParameters>]
```

## Description

`New-Logger` creates a new logger configuration that is passed through the pipeline to other cmdlets to set up sinks, and finally starts the logger with [`Start-Logger`](Start-Logger.md).

It's the first cmdlet used to set up a logger. If you want a simpler/faster solution, use [`Start-Logger`](Start-Logger.md) — short version.

> Implemented as the compiled `NewLoggerCommand` cmdlet class in `PoShLog.Core.dll` (`src/dotnet/Cmdlets/Core/NewLoggerCommand.cs`).

## Examples

Set up a logger that logs into `"C:\Logs\test.log"` and the console host.

```ps1
New-Logger |
    Add-SinkFile -Path "C:\Logs\test.log" |
    Add-SinkConsole |
    Start-Logger
```

## JSON configuration (v3)

Optional `-ConfigurationPath <string>` reads the `Serilog` section of a JSON file
once, resolving its path against the PowerShell FileSystem location. Missing files,
malformed JSON and missing sections fail configuration. Import extensions before
loading JSON. The returned configuration can continue through the normal pipeline.
See [JSON configuration](../guides/json-configuration.md) for the schema and supported sinks.
