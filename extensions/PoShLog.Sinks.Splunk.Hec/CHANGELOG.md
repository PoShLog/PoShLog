# Changelog

## 0.1.0 — unreleased

### Features
- New `Add-SinkSplunk` sends log events to a Splunk HTTP Event Collector. The event endpoint gets Splunk JSON; the
  raw endpoint (`-Endpoint Raw`) gets text lines rendered with `-OutputTemplate`.
- New `-Index`, `-Source`, `-SourceType`, `-HostName` and `-Fields` (indexed fields) parameters.
- Batching with `-BatchInterval`, `-BatchSizeLimit` and `-QueueLimit`.
- A level filter, a level switch and a custom HTTP handler.
- The parameter names of the third-party PoShLog.Sinks.Splunk still bind: `-SplunkHost`, `-EventCollectorToken`,
  `-BatchIntervalSeconds`.

### Changes
- Requires PoShLog 2.99.0 and PowerShell 7.4 or newer.
- `-BatchInterval` accepts fractions of a second.
- The queue is bounded at 100000 events by default.

### Bug fixes
- An empty `-Fields` table no longer produces invalid JSON.
