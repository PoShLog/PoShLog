# Cmdlets

PoShLog v3.0.0+ is a **compiled C# binary module** (`PoShLog.Core.dll`). All cmdlets below are implemented as `PSCmdlet`/`Cmdlet` classes, but keep the **same names, parameters, aliases, and pipeline behavior** as prior script-based versions.

*Note: cmdlets marked as* **`EXTENSION`** *must be installed separately as a companion module. See each cmdlet's documentation for more information.*

## Core cmdlets

* **[New-Logger](New-Logger.md)** - Creates new logger configuration
* **[Start-Logger](Start-Logger.md)** - Creates new instance of logger, that writes to configured sinks
* **[Close-Logger](Close-Logger.md)** - Resets Logger to the default and disposes the original if possible
* **[Get-Logger](Get-Logger.md)** - Gets the current logger stored in `[Serilog.Log]::Logger`
* **[Set-Logger](Set-Logger.md)** - Sets the given logger as the global static logger

## LevelSwitch cmdlets

* **[New-LevelSwitch](New-LevelSwitch.md)** - Creates instance of LoggingLevelSwitch at the initial minimum level
* **[Set-LevelSwitch](Set-LevelSwitch.md)** - Sets minimum level of given level switch
* **[Set-MinimumLevel](Set-MinimumLevel.md)** - Sets current minimum level of logger configuration

## Sink cmdlets

* **[Add-SinkConsole](Add-SinkConsole.md)** - Writes log events to console host
* **[Add-SinkPowerShell](Add-SinkPowerShell.md)** - Writes log events into PowerShell streams
* **[Add-SinkFile](Add-SinkFile.md)** - Writes log events to the specified file
* **[Add-SinkExceptionless](../sinks/Add-SinkExceptionless.md)** - Writes log events into [exceptionless.com](https://exceptionless.com/) **`EXTENSION`**
* **[Add-SinkEventLog](../sinks/Add-SinkEventLog.md)** - Writes log events into Windows Event Log **`EXTENSION`**
* **[Add-SinkElasticsearch](https://github.com/mamidenn/PoShLog.Sinks.Elasticsearch)** - Writes log messages to Elasticsearch **`EXTENSION`**
* **[Add-SinkSeq](https://github.com/PoShLog/PoShLog.Sinks.Seq)** - Writes log messages to Seq **`EXTENSION`**
* **[Add-SinkMSSqlServer](../sinks/Add-SinkMSSqlServer.md)** - Writes log messages into a MSSQL server database **`EXTENSION`**

## Enrichment cmdlets

* **[Add-EnrichFromLogContext](Add-EnrichFromLogContext.md)** - Enriches log events with properties pushed onto the ambient LogContext
* **[Add-EnrichWithErrorRecord](Add-EnrichWithErrorRecord.md)** - Enriches log events with ErrorRecord property if available
* **[Add-EnrichWithProperty](Add-EnrichWithProperty.md)** - Enriches log events with a custom property
* **[Add-EnrichWithEnvironment](../enrichers/Add-EnrichWithEnvironment.md)** - Enriches events with information from the process environment **`EXTENSION`**
* **[Add-EnrichWithExceptionDetails](../enrichers/Add-EnrichWithExceptionDetails.md)** - Adds additional structured properties from exceptions into log events **`EXTENSION`**
* **[Add-EnrichWithProcessId](../enrichers/Add-EnrichWithProcessId.md)** - Enriches log events with current process id **`EXTENSION`**
* **[Add-EnrichWithProcessName](../enrichers/Add-EnrichWithProcessName.md)** - Enriches log events with current process name **`EXTENSION`**

## Write cmdlets

* **[Write-VerboseLog](Write-VerboseLog.md)** - Write a log event with the Verbose level
* **[Write-DebugLog](Write-DebugLog.md)** - Write a log event with the Debug level
* **[Write-InfoLog](Write-InfoLog.md)** - Write a log event with the Information level (alias of `Write-InformationLog`)
* **[Write-WarningLog](Write-WarningLog.md)** - Write a log event with the Warning level
* **[Write-ErrorLog](Write-ErrorLog.md)** - Write a log event with the Error level
* **[Write-FatalLog](Write-FatalLog.md)** - Write a log event with the Fatal level

## Formatters

* **[Get-JsonFormatter](Get-JsonFormatter.md)** - Returns new instance of `Serilog.Formatting.Json.JsonFormatter`

## Helpers

* **[Convert-LogFunctions](Convert-LogFunctions.md)** - Converts default `Write-*` cmdlets in a script file into PoShLog `Write-*Log` cmdlets
