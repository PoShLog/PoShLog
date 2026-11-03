# Cmdlets

PoShLog v3 is a compiled binary module. This index preserves the wiki's command groups and includes v3 commands.

*Note: All cmdlets marked as* **`EXTENSION`** *must be installed separately! See each cmdlet documentation for more information.*

## Core cmdlets

* **[New-Logger](New-Logger.md)** - Creates new logger configuration
* **[Start-Logger](Start-Logger.md)** - Creates new instance of logger, that writes to configured sinks
* **[Close-Logger](Close-Logger.md)** - Resets Logger to the default and disposes the original if possible

* **[Get-Logger](Get-Logger.md)** - Gets the current global logger.
* **[Set-Logger](Set-Logger.md)** - Sets the global logger.

## LevelSwitch cmdlets

* **[New-LevelSwitch](New-LevelSwitch.md)** - Creates instance of LoggingLevelSwitch at the initial minimum level
* **[Set-LevelSwitch](Set-LevelSwitch.md)** - Sets minimum level of given level switch.
* **[Set-MinimumLevel](Set-MinimumLevel.md)** - Sets current minimum level of logger configuration

## Sink cmdlets

* **[Add-SinkConsole](Add-SinkConsole.md)** - Writes log events to console host
* **[Add-SinkPowerShell](Add-SinkPowerShell.md)** - Writes log events into PowerShell streams
* **[Add-SinkFile](Add-SinkFile.md)** - Write log events to the specified file
* **[Add-SinkExceptionless](../sinks/Add-SinkExceptionless.md)** - Write log events into [exceptionless.com](https://exceptionless.com/) **`EXTENSION`**
* **[Add-SinkEventLog](../sinks/Add-SinkEventLog.md)** - Writes log events into Windows Event Log **`EXTENSION`**
* **[Add-SinkElasticsearch](https://github.com/mamidenn/PoShLog.Sinks.Elasticsearch)** - Writes log messages to Elasticsearch [**`EXTENSION`**](https://github.com/mamidenn/PoShLog.Sinks.Elasticsearch)
* **[Add-SinkSeq](https://github.com/PoShLog/PoShLog.Sinks.Seq)** - Writes log messages to Seq [**`EXTENSION`**](https://github.com/PoShLog/PoShLog.Sinks.Seq)
* **[Add-SinkMSSqlServer](../sinks/Add-SinkMSSqlServer.md)** - Writes log messages into MSSQL server database [**`EXTENSION`**](https://github.com/PoShLog/PoShLog.Sinks.MSSqlServer)

## Enrichment cmdlets

* **[Add-EnrichFromLogContext](Add-EnrichFromLogContext.md)** - Adds properties from the ambient LogContext.
* **[Push-LogContextProperty](Push-LogContextProperty.md)** - Adds properties to every event logged within a scope

* **[Add-EnrichWithErrorRecord](Add-EnrichWithErrorRecord.md)** - Enriches log events with ErrorRecord property if available
* **[Add-EnrichWithProperty](Add-EnrichWithProperty.md)** - Enriches log events with custom property
* **[Add-EnrichWithEnvironment](../enrichers/Add-EnrichWithEnvironment.md)** - Enriches events with information from the process environment **`EXTENSION`**
* **[Add-EnrichWithExceptionDetails](../enrichers/Add-EnrichWithExceptionDetails.md)** - Adds additional structured properties from exceptions into log events **`EXTENSION`**
* **[Add-EnrichWithProcessId](../enrichers/Add-EnrichWithProcessId.md)** - Enriches log events with current process id **`EXTENSION`**
* **[Add-EnrichWithProcessName](../enrichers/Add-EnrichWithProcessName.md)** - Enriches log events with current process name **`EXTENSION`**

## Write cmdlets

* **[Write-VerboseLog](Write-VerboseLog.md)** - Write a log event with the Verbose level.
* **[Write-DebugLog](Write-DebugLog.md)** - Write a log event with the Debug level.
* **[Write-InformationLog](Write-InfoLog.md)** - Write a log event with the Information level.
* **[Write-WarningLog](Write-WarningLog.md)** - Write a log event with the Warning level.
* **[Write-ErrorLog](Write-ErrorLog.md)** - Write a log event with the Error level.
* **[Write-FatalLog](Write-FatalLog.md)** - Write a log event with the Fatal level.

## Formatters

* **[Get-JsonFormatter](Get-JsonFormatter.md)** - Returns new instance of `Serilog.Formatting.Json.JsonFormatter`
* **[Get-CompactFormatter](Get-CompactFormatter.md)** - Returns a formatter that writes the Compact Log Event Format (CLEF)

## Helpers

* **[Convert-LogFunctions](Convert-LogFunctions.md)** - Converts Write commands in a script into PoShLog commands.

The v3 commands Add-SinkLogger, Get-CurrentLogFiles, Set-DefaultMessageFormatter, Enable-SelfLog and Disable-SelfLog also expose PowerShell help through Get-Help.

See also [write cmdlets](Write-cmdlets.md) and the [v3 migration guide](../guides/migration-v3.md).
