# Extension modules

PoShLog is extensible, just like Serilog. To add more cmdlets, install one of the following modules:

* [**PoShLog.Enrichers**](https://github.com/PoShLog/PoShLog.Enrichers) - Helpful enricher methods for adding more properties to log messages.
* [**PoShLog.Sinks.Exceptionless**](https://github.com/PoShLog/PoShLog.Sinks.Exceptionless) - Publishes log messages to [Exceptionless.com](https://exceptionless.com/).
* [**PoShLog.Sinks.EventLog**](https://github.com/PoShLog/PoShLog.Sinks.EventLog) - Publishes log messages to Windows Event Log.
* [**PoShLog.Sinks.Syslog.Rfc5424**](../sinks/Add-SinkSyslog.md) - Publishes log messages to syslog servers over UDP, TCP or TLS.
* [**PoShLog.Sinks.Syslog**](https://github.com/gitbute/PoShLog.Sinks.Syslog) - Another author's syslog sink; import only one of the two.
* [**PoShLog.Sinks.Elastic**](../sinks/Add-SinkElasticsearch.md) - Publishes log messages to Elasticsearch or Elastic Cloud data streams.
* [**PoShLog.Sinks.Elasticsearch**](https://github.com/mamidenn/PoShLog.Sinks.Elasticsearch) - Another author's Elasticsearch sink, for Windows PowerShell and PoShLog 2.x.
* [**PoShLog.Sinks.Seq**](https://github.com/PoShLog/PoShLog.Sinks.Seq) - Publishes log messages to [Seq](https://datalust.co/seq).
* [**PoShLog.Sinks.MSSqlServer**](https://github.com/PoShLog/PoShLog.Sinks.MSSqlServer) - Writes log messages into a MSSQL server database.

> **Compatibility note:** extension modules must target the same runtime as the core module. Since PoShLog v3.0.0, the core module is a compiled .NET 8 binary module requiring PowerShell 7.0+. Older script-based extension modules built against the previous PoShLog script module should continue to work as long as they only call the public cmdlets documented here, but any extension shipping its own compiled binaries should be rebuilt/verified against .NET 8 and Serilog 4.x for full compatibility.
