# Usage

## Quick info

In order to log, you'll want to set a minimum level (below which no events are generated), add locations (sinks) to write event messages to, and optionally add message [enrichments](guides/enrichers.md).

## Sinks

First, you need to understand sinks. Sinks are locations where we want to log our messages — for example a file sink that logs into a file, a console sink that outputs to the console host, and so on. See the [supported sinks](sinks/README.md).

You can see all Serilog (the C# library PoShLog is built upon) sinks [here](https://github.com/serilog/serilog/wiki/Provided-Sinks), but keep in mind PoShLog only supports a subset of them out of the box. If you'd like to see a sink added, please raise an [issue](https://github.com/PoShLog/PoShLog/issues).

## Starting logger

In order to log your messages into the desired sinks, you need to create a logger first. You have two options, and which one to choose depends on how much customization you need.

### Short version

To create and start a logger quickly, use the [`Start-Logger`](cmdlets/Start-Logger.md) cmdlet. It allows you to choose between Console and File sinks only, with a handful of settings: `-MinimumLevel`, `-FilePath`, and `-FileRollingInterval`. If you need more customization, see [Full version](#full-version).

##### Example 1: Start-Logger — log into file `C:\Data\my_awesome.log` and console

```ps1
Import-Module PoShLog

# Create and start new logger
Start-Logger -FilePath 'C:\Data\my_awesome.log' -Console

Write-InfoLog 'Hurrray, my first log message'
Write-ErrorLog 'Oops, error occurred!'

# Don't forget to close the logger
Close-Logger
```

### Full version

To get maximum functionality out of PoShLog, configure the logger with the [`New-Logger`](cmdlets/New-Logger.md) cmdlet. This lets you set up the logger via the pipeline — a very similar approach to the C# fluent API. You can add as many sinks as you want, add enrichments, and set the initial minimum level. See [`New-Logger`](cmdlets/New-Logger.md), [`Add-SinkFile`](cmdlets/Add-SinkFile.md), [`Add-SinkConsole`](cmdlets/Add-SinkConsole.md), and [`Start-Logger`](cmdlets/Start-Logger.md) for more.

##### Example 2: Log into file `C:\Data\my_awesome-*.log` with daily rolling and console, both at minimum level `Verbose`

```ps1
Import-Module PoShLog

# Create new logger
New-Logger | # Create new instance of logger configuration
    Set-MinimumLevel -Value Verbose | # Set minimum level, below which no events should be generated
    Add-SinkFile -Path 'C:\Data\my_awesome-.log' -RollingInterval Day | # Write event messages into file
    Add-SinkConsole | # Write event messages into console host
    Start-Logger # Start logging

# Write few messages to test functionality
Write-VerboseLog 'Test verbose message'
Write-DebugLog 'Test debug message'

# Close logger to release all resources, like the log file
Close-Logger
```

#### Output templates

Text-based sinks use output templates to control message formatting. Modify this formatting with the `-OutputTemplate` parameter:

```ps1
Add-SinkFile -Path 'log.txt' -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}'
```

The example above shows the default template, using built-in properties like `Level` and `Timestamp`. You can add more properties using [enrichers](guides/enrichers.md). Add `{Properties:j}` to the output template to include additional context information.
See the [Serilog documentation](https://github.com/serilog/serilog/wiki/Configuration-Basics#output-templates).

#### Minimum level

Minimum level sets the log event level below which no events will be generated.

##### Example 3: Setting minimum level to `Debug`

In this example, minimum level is set to `Debug` — messages with level `Debug` and higher (`Information`, `Warning`, `Error`, `Fatal`) will be processed and, in this case, written to console. Messages at a lower level (`Verbose` via `Write-VerboseLog`) will be ignored. Default minimum level is `Information`.

```ps1
New-Logger |
    Set-MinimumLevel -Value Debug |
    Add-SinkConsole |
    Start-Logger
```

See all log event levels [here](log-event-levels.md).

#### Overriding minimum level per sink

Every provided sink supports the `-RestrictedToMinimumLevel` parameter, useful when you want detailed logs in one location but less detailed in another. **Keep in mind that the minimum level for a sink can only be raised.**

##### Example 4: Overriding minimum log level for the Console sink

Here, debug and higher messages will be written to the file, while `Information` and higher will be written to console.

```ps1
New-Logger |
    Set-MinimumLevel -Value Debug |
    Add-SinkFile -Path 'log.txt' |
    Add-SinkConsole -RestrictedToMinimumLevel Information |
    Start-Logger
```

## Write messages

Logging is all about writing event messages. PoShLog offers 6 levels of messages: `Verbose`, `Debug`, `Information`, `Warning`, `Error`, `Fatal` — via 6 cmdlets: `Write-VerboseLog`, `Write-DebugLog`, `Write-InfoLog`, `Write-WarningLog`, `Write-ErrorLog`, `Write-FatalLog`. It's up to you to decide where to place them in your code and what level to choose. You can decide later which messages are generated, depending on level, using [`Set-MinimumLevel`](cmdlets/Set-MinimumLevel.md) or [`Set-LevelSwitch`](cmdlets/Set-LevelSwitch.md).

##### Example 5: Write all levels of messages into console

```ps1
Import-Module PoShLog

Start-Logger # Short version

# Test all log levels
Write-VerboseLog 'Test verbose message'
Write-DebugLog 'Test debug message'
Write-InfoLog 'Test info message'
Write-WarningLog 'Test warning message'
Write-ErrorLog 'Test error message'
Write-FatalLog 'Test fatal message'

Close-Logger
```

## Log objects

Put `@` in front of a property name to log an object with its structure instead of as its string form:

```ps1
$service = Get-Service EventLog | Select-Object Name, Status, @{ l = 'Since'; e = { (Get-Date).Date } }
Write-InfoLog 'Checked {@Service}' -PropertyValues $service
# Checked {"Name": "EventLog", "Status": "Running", "Since": "2026-11-03T00:00:00.0000000+01:00"}
```

- A `[pscustomobject]` (also from `Select-Object`, `ConvertFrom-Json` or `Import-Csv`) is logged with its properties only: note, script and calculated properties are kept, PowerShell's adapter members are not.
- A hashtable or `[ordered]` dictionary is logged as a JSON object.
- An object that refers back to itself is cut with `"[Circular]"`, and nesting stops at 10 levels.
- Other .NET objects (`Get-Item`, `Get-Service` without `Select-Object`) are logged with all their public properties, which can be a lot. Select the properties you need, or lower the depth with `$config.Destructure.ToMaximumDepth(3)` on the configuration from `New-Logger`.

To add the same property to every event in a block of code, see [`Push-LogContextProperty`](cmdlets/Push-LogContextProperty.md). The rules are in [ADR 0005](decisions/0005-psobject-destructuring-policy.md).

## Close logger

Don't forget to close the logger at the end of every session. This releases all resources safely.
