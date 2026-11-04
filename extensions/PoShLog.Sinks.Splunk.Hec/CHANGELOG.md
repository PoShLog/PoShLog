# Changelog

## Unreleased

### Features
- No new features.

### Changes
- Requires PowerShell 7.6 or newer and is built for .NET 10 (ADR 0033). This is a breaking change on PowerShell 7.4 and 7.5: stay on the previous version there, or on PoShLog 2.x with the 1.0.x extensions.

### Bug fixes
- None.

## 0.1.0-preview2 — 2026-11-03

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
