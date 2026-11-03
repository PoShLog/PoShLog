# 0003 — v3 keeps the v2 extension contract

- **Status:** accepted (Tomáš, 2026-11-03); amended by [0009](0009-first-party-sinks-third-party-check-non-blocking.md), [0010](0010-v2-maintenance-line.md)
- **Date:** 2026-11-03

## Context

Extension modules, including third-party ones we cannot change, rely on this v2 contract:

1. `New-Logger` emits a `[Serilog.LoggerConfiguration]` that is piped through `Add-Sink*`/`Add-Enrich*` functions
   and into `Start-Logger`. The functions call Serilog extension methods directly, e.g.
   `[Serilog.SeqLoggerConfigurationExtensions]::Seq($LoggerConfig.WriteTo, …)`, and return the configuration.
2. Each extension `Add-Type`s its own `lib/*.dll`: the sink assembly plus netstandard facades. All of them go into
   the **default AssemblyLoadContext**, next to whatever Serilog PoShLog loaded. Most ship no Serilog.dll and bind
   to PoShLog's copy.
3. Load order is guaranteed by `RequiredModules` (PoShLog >= 2.0.0, by GUID), so PoShLog's Serilog loads first.
4. Some extensions also use `[Serilog.Events.LogEventLevel]`, `[Serilog.Core.LoggingLevelSwitch]`, `LevelAlias` and
   `Write-*Log` with `-Logger`.

The v3 binary module keeps all four. It exports every v2 command (22 v2 exports, all present in v3, plus 6 new
ones), still emits `Serilog.LoggerConfiguration`, and loads Serilog 4.2 into the default context. On .NET a reference
to Serilog 2.0.0.0 binds to the already loaded 4.2.0.0. **Verified 2026-11-03:** PoShLog.Sinks.Seq 1.0.0 (v2-era,
built from its own source) imported on the v3 build in PowerShell 7.6.9. `New-Logger | Add-SinkSeq | Start-Logger`
delivered events to a local HTTP listener (`POST /api/events/raw`, both events with properties). The migration
guide's FAQ says v2 extensions do not work with v3; that is wrong and has to be corrected.

## Decision

**Keep the v2 contract as a compatibility guarantee of v3.x**, and prove it in CI:

- No AssemblyLoadContext isolation for Serilog. Sinks must share Serilog's types with Core.
- No compatibility shim. No v2 export is removed; `Add-PackageTypes` and `Test-PsCore` were never exported.
- Core loads its dependencies at import, and every Serilog package Core ships is at least the version any known
  extension ships. A newer one satisfies older references; an older one does not.
- A **compatibility suite** in CI installs the published extensions listed in ADR 0002 (ours and third-party)
  against the freshly built Core. Each one must import and push an event through its sink to a local listener.
  A failure blocks the release.
- Windows PowerShell 5.1 stays on v2 (ADR 0001). A final **2.2.0** (the 2021 preview promoted, issue #44) is the
  maintained 5.1 line for security and critical fixes only.

## Alternatives considered

- **ALC isolation plus binding redirects.** It protects Core from foreign Serilog copies, but then the
  `LoggerConfiguration` an extension receives is a different type from the one it compiled against. That breaks
  every extension, which is exactly the contract we must keep.
- **A compat shim module.** There is nothing to shim, because the surface is a superset.
- **A hard major break with a migration guide.** It would strand the third-party sinks (DataDog, ElmahIo, Splunk,
  Syslog), whose authors may never update them.
- **Keeping v2 fully maintained in parallel.** It doubles the work for a 5.1 audience. A security-only 2.2.x is enough.

## Consequences

- Serilog major upgrades in Core (5.x one day) must pass the compatibility suite. If one cannot, it needs a new
  ADR and a major version.
- An extension that ships its own Serilog.dll (Elasticsearch) can still conflict, but it is Desktop-only already.
  The docs say so.
- Running third-party modules in CI is a supply-chain trade-off. They run in an ephemeral GitHub runner and pin exact
  versions.
