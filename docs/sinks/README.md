# Sinks

Sinks are locations where we want to log our event messages — for example a file sink that logs into a file, a console sink that outputs to the console host, and so on.

You can see all Serilog (the C# library PoShLog is built upon) sinks [here](https://github.com/serilog/serilog/wiki/Provided-Sinks), but keep in mind PoShLog only supports a subset of them out of the box. If you'd like a sink added, please raise an [issue](https://github.com/PoShLog/PoShLog/issues).

## Core sinks

* [**Add-SinkConsole**](../cmdlets/Add-SinkConsole.md)
* [**Add-SinkFile**](../cmdlets/Add-SinkFile.md)
* [**Add-SinkPowerShell**](../cmdlets/Add-SinkPowerShell.md)

## Extensions

**`These sinks must be installed separately! See each cmdlet's documentation for more information.`**

* [**Add-SinkElasticsearch**](Add-SinkElasticsearch.md) - Elasticsearch or Elastic Cloud data streams, as ECS documents (PoShLog.Sinks.Elastic)
* [**Add-SinkEventLog**](Add-SinkEventLog.md)
* [**Add-SinkExceptionless**](Add-SinkExceptionless.md)
* [**Add-SinkMSSqlServer**](Add-SinkMSSqlServer.md)
* [**Add-SinkNotepad**](Add-SinkNotepad.md)
* [**Add-SinkOpenTelemetry**](Add-SinkOpenTelemetry.md) - OTLP to Seq, Grafana, Aspire, Datadog, Splunk, Elastic or any OpenTelemetry Collector
* [**Add-SinkSeq**](https://github.com/PoShLog/PoShLog.Sinks.Seq)
* [**Add-SinkSplunk**](Add-SinkSplunk.md) - Splunk HTTP Event Collector, event or raw endpoint (PoShLog.Sinks.Splunk.Hec)
* [**Add-SinkSyslog**](Add-SinkSyslog.md) - syslog over UDP, TCP or TLS, RFC 5424 or RFC 3164 (PoShLog.Sinks.Syslog.Rfc5424)

## Third-party sinks

These modules are maintained separately. The pinned versions listed below are checked in CI against v3; install them separately.

| Module | Maintainer | CI version | Platform |
|---|---|---|---|
| [PoShLog.Sinks.DataDog](https://www.powershellgallery.com/packages/PoShLog.Sinks.DataDog) | Chris Hunt | 0.1.1 | PowerShell Core; Windows only (0.1.1 does not import on Linux: its manifest names `PoShLog.Sinks.Datadog.psm1` with different casing) |
| [PoShLog.Sinks.ElmahIo](https://www.powershellgallery.com/packages/PoShLog.Sinks.ElmahIo) | elmah.io | 4.0.4 | PowerShell Core |
| [PoShLog.Sinks.Splunk](https://www.powershellgallery.com/packages/PoShLog.Sinks.Splunk) | Mike Powell | 1.0.4 | PowerShell Core; the first-party alternative is PoShLog.Sinks.Splunk.Hec ([Add-SinkSplunk](Add-SinkSplunk.md)), import only one of the two |
| [PoShLog.Sinks.Syslog](https://www.powershellgallery.com/packages/PoShLog.Sinks.Syslog) | Michael Zimmerli | 1.0.0 | PowerShell Core; the first-party alternative is PoShLog.Sinks.Syslog.Rfc5424 ([Add-SinkSyslog](Add-SinkSyslog.md)), import only one of the two |
| [PoShLog.Sinks.Elasticsearch](https://github.com/mamidenn/PoShLog.Sinks.Elasticsearch) | mamidenn | Excluded | Windows PowerShell only; use PoShLog 2.x. On PowerShell 7 the first-party alternative is PoShLog.Sinks.Elastic ([Add-SinkElasticsearch](Add-SinkElasticsearch.md)) |
