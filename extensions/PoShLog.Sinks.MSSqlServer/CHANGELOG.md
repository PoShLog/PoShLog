# Changelog

## 2.0.0-preview3 — 2026-11-04

### Features
- First-party binary Add-SinkMSSqlServer for PowerShell 7.4+, PoShLog 3 and Serilog 4.4.
- Configurable standard columns, additional SQL columns, LogEvent JSON, batching and minimum levels.

### Changes
- Serilog.Sinks.MSSqlServer 10.0.0 and Microsoft.Data.SqlClient / Extensions.Azure 7.1.1.
- Managed identity uses connection string Authentication instead of the old Azure token parameters.
- 2.0.0 marks the runtime floor change; preview3 follows Core's preview label (ADR 0019).

### Bug fixes
- Isolate SqlClient, Microsoft.Extensions and Azure dependencies from other modules (MSSqlServer#1).
- Package all runtime dependencies and platform assets to avoid missing SinkOptions types (MSSqlServer#2).
