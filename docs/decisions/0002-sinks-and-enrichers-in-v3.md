# 0002 — Which sinks and enrichers v3 keeps

- **Status:** proposed (awaiting Tomáš)
- **Date:** 2026-11-03

## Context

v2 has a family of extension modules, each in its own GitHub repo. Each requires PoShLog 2.x and bundles a
Serilog 2.x sink. None of them loads next to v3, because Serilog 4 sits in the same AssemblyLoadContext. Their state
on 2026-11-03 (PowerShell Gallery total downloads, last push):

| Module | Gallery | Downloads | Last push | Note |
|---|---|---|---|---|
| PoShLog.Enrichers | 1.0.0 | ~250k | 2020 | Environment, Process, Thread, Serilog.Exceptions |
| PoShLog.Sinks.Seq | 1.0.0 | ~164k | 2023 | |
| PoShLog.Sinks.EventLog | 1.0.0 | ~4k | 2022 | Windows only; open issue #4 is about non-Windows |
| PoShLog.Sinks.Exceptionless | 1.0.0 | ~3k | 2020 | |
| PoShLog.Sinks.Http | 1.0.1 | ~1k | 2023 | |
| PoShLog.Sinks.MSSqlServer | 1.0.0-preview1 | ~0.5k | 2021 | never left preview; issue #1 is a SqlClient conflict with PnP.PowerShell |
| PoShLog.Sinks.Notepad | — | — | 2023 | never published |
| PoShLog.Sinks.Template, PoShLog.Tools | — | — | 2021–22 | scaffolding and v2 build scripts |
| Sinks.Elasticsearch, Sinks.Syslog | community | <1k | 2020–22 | other authors |

The v3 docs already describe using any Serilog sink package without a wrapper module.

## Decision

- **Fold the enrichers into Core** as `Add-EnrichWithEnvironment`, `Add-EnrichWithProcess`, `Add-EnrichWithThread`
  and `Add-EnrichWithExceptionDetails`. The packages are small and dependency-light, and the enrichers are the
  second most used module. Moving them into Core removes one version-lock between modules.
- **Keep three sinks as separate modules: Seq, EventLog and Http.** Each is ported to Serilog 4 and built from the
  PoShLog repo under `sinks/`, with the same CI and Serilog version as Core and a published `RequiredModules`
  PoShLog 3.0.0. EventLog stays separate because it is Windows only, and Core stays cross-platform.
- **Retire** Exceptionless, MSSqlServer, Notepad, Template and Tools. Their repos get a final README pointing to
  v3 and to the "any Serilog sink" guide, and are then archived. The published v2-era Gallery versions stay as they
  are. Community sinks are listed in the docs as v2-only until their authors port them.

## Alternatives considered

- **Port every sink.** It quadruples the release work for modules with a few hundred to a few thousand downloads,
  and MSSqlServer's SqlClient dependency is the main source of assembly conflicts.
- **Fold Seq and Http into Core.** Fewer modules, but every user downloads HTTP and Seq clients they do not use.
  Their release cadence is also not Core's.
- **Keep one repo per sink.** That is how v2 drifted: each repo pinned its own Serilog, and nothing tested them
  together.

## Consequences

- The PoShLog repo becomes a small monorepo: `src/` for Core and `sinks/{Seq,EventLog,Http}`. Release workflows
  publish each module separately.
- The old sink repos need a README change and archiving. Both are GitHub writes that need Tomáš's yes.
