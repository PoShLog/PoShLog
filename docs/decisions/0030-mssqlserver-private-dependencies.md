# 0030 — MSSqlServer isolates dependencies and shares Serilog with Core

- **Status:** Proposed
- **Date:** 2026-11-03
- **Amends:** [0002](0002-sinks-and-enrichers-in-v3.md) (MSSqlServer returns as a first-party extension),
  [0003](0003-keep-the-v2-extension-contract.md) and [0011](0011-core-does-not-load-assemblies-extensions-ship.md)
  (private dependencies can be isolated while Serilog remains shared).

## Context

The Gallery has only MSSqlServer 1.0.0-preview1. [Issue #1](https://github.com/PoShLog/PoShLog.Sinks.MSSqlServer/issues/1)
reports a conflict with PnP.PowerShell's DI Abstractions 2.2.0.0. Issue #2 reported missing SinkOptions types.
Add-Type of every DLL exposes both version conflicts and incomplete packages.

## Decision

Ship PoShLog.Sinks.MSSqlServer in the monorepo, targeting net8.0 for PowerShell 7.4's .NET 8 host (ADR 0001).
The thin binary cmdlet references only PowerShell, framework types and Serilog 4.4.0. It invokes a worker in a dedicated
non-collectible AssemblyLoadContext through reflection. The context lives for the process because batched sinks can
outlive the configuring cmdlet; logger disposal flushes and disposes them.

The context explicitly returns Core's Serilog assembly. LoggerConfiguration, LoggingLevelSwitch and ITextFormatter
retain their identities, preserving ADR 0003's pipeline. Share the host's System.Diagnostics.DiagnosticSource too:
Serilog's LogEvent exposes ActivityTraceId/ActivitySpanId, and a private copy breaks their method signatures at emission.
Framework types and data-only dictionaries cross the boundary;
SQL-specific options stay private. The manifest preserves the original module GUID.

AssemblyDependencyResolver reads the worker's deps.json and selects platform implementations and native assets.
Package dependencies resolve privately, including Microsoft.Extensions.*, Azure.Identity and SqlClient's Azure extension.
Missing non-framework packages fail with a rebuild/reinstall diagnostic rather than binding to another module's packages.
The deps.json package list also prevents missing package-supplied System.* DLLs from falling back to another module.
Framework resolution is delegated to the runtime. Private DLLs are never Add-Typed into PowerShell's context.

Pin Serilog.Sinks.MSSqlServer 10.0.0 and Microsoft.Data.SqlClient / Extensions.Azure 7.1.1. SqlClient 7 moved Azure auth
to a separate package, which is included. Packaging preserves the complete publish tree, deps.json, RID-specific managed
assemblies and Windows x64 native SNI. Linux x64 uses managed SNI; no Linux native SNI DLL is required. No private
Serilog.dll ships. Preserve runtime folders when staging the module.

ColumnOptions accepts dictionaries with Store, AdditionalColumns and nested upstream settings, including LogEvent JSON.
Unknown settings fail explicitly. Keep the v1 connection, table, schema, batching, minimum-level, Formatter and
FormatProvider names. Replace obsolete UseAzureManagedIdentity and AzureServiceTokenProviderResource with SqlClient's
Authentication connection-string option; document this migration.

Version **2.0.0-preview3** follows ADRs 0004 and 0019: refreshing an existing 1.x module with a breaking runtime floor
deserves 2.0.0, unlike new sinks starting at 0.1.0. preview3 matches the next Core preview rather than numbering this
extension's previews independently. RequiredModules stays 2.99.0 by GUID during the Core prerelease (ADR 0017).
Core's own version is unchanged here.

## Verification

Test-MSSqlServerIsolation.ps1 loads the real NuGet DI Abstractions 2.2.0.0 in the default context and constructs the sink,
then repeats in reverse order in fresh pwsh processes. It resolves modern DI types and private SqlClient/Azure assemblies,
and confirms the old assembly's identity. With POSHLOG_SQL_CONNECTION_STRING each order writes and reads a real SQL row.
All three compat modes execute it. Published tests the new build beside published Seq; it does not repair the old SQL preview.

SQL integration creates a real table, writes Information/Warning/Error with properties and an exception, flushes batches,
then reads messages, levels, additional columns, Properties XML and LogEvent JSON. CI uses disposable SQL Server 2022 with
an ephemeral credential passed through environment variables. Unit tests cover column mapping and invalid configuration.

## Alternatives considered

- Reuse an already loaded newer package: fails when an older package loads first, and changes other modules.
- Isolate Serilog too: breaks type identity and the logger pipeline.
- Change DLL load order: reverses which module fails.
- Rename assemblies: requires rewriting transitive references and complicates runtime asset selection.

## Consequences

The package is larger but carries its full dependency tree. Close-Logger flushes batches. Import alone does not connect;
auto-create during configuration needs DDL permissions. Never write connection strings to diagnostics.

Evaluate this pattern for other dependency-heavy extensions, especially Elastic and OpenTelemetry. This branch changes
neither. Isolation protects managed assembly identity; process-wide native behavior and actual PnP authentication need
separate testing. The conflict fixture is an actual old DI package, not PnP.PowerShell. macOS and non-x64 platforms are
not claimed by the new extension's platform tags.
