# 0002 — Which sinks and enrichers v3 keeps

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03

## Context

v2 has a family of extension modules. Each is a script module that dot-sources `Add-Sink*`/`Add-Enrich*`
functions and `Add-Type`s a `lib/` folder of Serilog 2.x-era sink assemblies. Each declares `RequiredModules`
PoShLog `2.0.0` (a minimum, so 3.0.0 satisfies it). Published modules that depend on PoShLog (PowerShell Gallery,
2026-11-03):

| Module | Owner | Version | Published | Loads on PS 7 |
|---|---|---|---|---|
| PoShLog.Enrichers | ours | 1.0.0 | 2020-03 | yes |
| PoShLog.Sinks.Seq | ours | 1.0.0 | 2020-07 | yes |
| PoShLog.Sinks.EventLog | ours | 1.0.0 | 2020-07 | Windows only |
| PoShLog.Sinks.Exceptionless | ours | 1.0.0 | 2020-03 | yes |
| PoShLog.Sinks.Http | ours | 1.0.1 | 2023-11 | binary nested module |
| PoShLog.Sinks.MSSqlServer | ours | 1.0.0-preview1 | 2021-05 | own `Test-PSCore` |
| PoShLog.Sinks.Syslog | Michael Zimmerli | 1.0.0 | 2020-10 | yes |
| PoShLog.Sinks.Elasticsearch | mamidenn | 1.0.0-alpha5 | 2022-01 | **no** — `CompatiblePSEditions = 'Desktop'`, ships its own Serilog.dll |
| PoShLog.Sinks.DataDog | Chris Hunt | 0.1.1 | 2022-11 | yes |
| PoShLog.Sinks.ElmahIo | elmah.io | 4.0.4 | 2022-12 | yes |
| PoShLog.Sinks.Splunk | Mike Powell | 1.0.4 | 2024-01 | yes |

Backward compatibility with these modules, especially third-party ones, is a hard requirement (Tomáš, 2026-11-03).
See ADR 0003.

## Decision

- **Nothing is folded into Core under an existing extension's command names.** PoShLog.Enrichers keeps working
  as it is. Core must not export `Add-EnrichWithEnvironment` and similar names that would shadow it.
- **Our sinks stay separate modules and keep working unchanged on v3.** Refreshed versions (Serilog 4 deps,
  PS 7.4 manifest) for **Seq, EventLog, Http and Enrichers** are built from the PoShLog repo under `extensions/`, with
  one CI and one Serilog version. They keep their command names and parameters, and `RequiredModules` stays PoShLog
  `2.0.0`, so one version serves both lines where possible.
- **Exceptionless, MSSqlServer, Notepad, Template and Tools get no new versions.** Their published versions keep
  working where they work today. The repos get a README pointing to the docs, and are archived only with Tomáš's yes.
- New sinks (OpenTelemetry/OTLP first) are new modules in `extensions/`.

## Alternatives considered

- **Fold the enrichers into Core.** One module fewer, but it shadows PoShLog.Enrichers' commands, and that breaks
  the compatibility requirement for anyone importing both.
- **Port every sink.** It quadruples the release work for modules with a few hundred to a few thousand downloads.
- **Keep one repo per sink.** That is how v2 drifted: each repo pinned its own Serilog, and nothing tested them together.

## Consequences

- The PoShLog repo becomes a small monorepo (`src/` Core, `extensions/*`). Release workflows publish each module
  separately.
- Archiving the old repos and changing their READMEs are GitHub writes that need Tomáš's yes.
