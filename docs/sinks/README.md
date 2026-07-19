# Sinks

Sinks are locations where we want to log our event messages — for example a file sink that logs into a file, a console sink that outputs to the console host, and so on.

You can see all Serilog (the C# library PoShLog is built upon) sinks [here](https://github.com/serilog/serilog/wiki/Provided-Sinks), but keep in mind PoShLog only supports a subset of them out of the box. If you'd like a sink added, please raise an [issue](https://github.com/PoShLog/PoShLog/issues).

## Core sinks

* [**Add-SinkConsole**](../cmdlets/Add-SinkConsole.md)
* [**Add-SinkFile**](../cmdlets/Add-SinkFile.md)
* [**Add-SinkPowerShell**](../cmdlets/Add-SinkPowerShell.md)

## Extensions

**`These sinks must be installed separately! See each cmdlet's documentation for more information.`**

* [**Add-SinkElasticsearch**](https://github.com/mamidenn/PoShLog.Sinks.Elasticsearch)
* [**Add-SinkEventLog**](Add-SinkEventLog.md)
* [**Add-SinkExceptionless**](Add-SinkExceptionless.md)
* [**Add-SinkMSSqlServer**](Add-SinkMSSqlServer.md)
* [**Add-SinkNotepad**](Add-SinkNotepad.md)
* [**Add-SinkSeq**](https://github.com/PoShLog/PoShLog.Sinks.Seq)
* [**Add-SinkSyslog**](https://github.com/gitbute/PoShLog.Sinks.Syslog)
