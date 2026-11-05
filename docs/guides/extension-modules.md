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
* [**PoShLog.Sinks.MSSqlServer**](../sinks/Add-SinkMSSqlServer.md) - Writes batched events to SQL Server or Azure SQL with isolated SqlClient dependencies.

> Core repository builds target net472 for Windows PowerShell 5.1 and net10.0 for PowerShell 7.6+.
> Refreshed extensions still target net10.0 and declare Core edition. A Desktop extension needs its own runtime tests
> before adding Desktop to its manifest. The shared Serilog pipeline contract and version-bounded Desktop resolver
> support v2-era references. Published compatibility is tested in CI. See [compatibility](../compatibility.md).
