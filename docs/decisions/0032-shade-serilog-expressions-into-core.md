# 0032 — Shade Serilog.Expressions into Core

- **Status:** accepted (Tomáš, 2026-11-04)
- **Date:** 2026-11-04
- **Supersedes:** [0027](0027-conditional-sublogger-expressions.md)

## Context

`Add-SinkLogger -Filter` compiles Serilog expressions at configuration time and evaluates them on
background threads without a PowerShell runspace. Serilog.Expressions 5.0.0 exports
`Serilog.LoggerSinkConfigurationExtensions`, the same type name as the helper used by published
PoShLog.Sinks.Exceptionless 1.0.0. Loading both publicly breaks PowerShell type resolution and delivery.
ADR 0027 avoided this with a private AssemblyLoadContext while sharing Serilog with Core (ADR 0003).
We need a simpler private implementation that also serves the future Windows PowerShell 5.1 work
(ADR 0031, phase 2, recorded on that feature branch); the Desktop build is outside this implementation.

## Decision

Merge Serilog.Expressions 5.0.0 into PoShLog.Core.dll using pinned ILRepack.Lib.MSBuild.Task 2.0.44,
with internalization, in every Debug and Release build. Call its compiler directly and remove the
Expressions AssemblyLoadContext and reflection adapter. Retain existing filter semantics and errors.

Merge only Core and Expressions. Serilog, Serilog.Sinks.File and Serilog.Sinks.Console remain separate,
shared assemblies. Do not ship or load Serilog.Expressions.dll. Build from the original compiler output
on every invocation so incremental builds cannot merge an already merged assembly. Exclude Expressions
runtime assets and transitive package exposure; publishing and module staging retain the licence files.

## Alternatives considered

- **Private AssemblyLoadContext (ADR 0027):** works on PS7, but requires loader/reflection adaptation
  and has no equivalent on Windows PowerShell 5.1. Shading keeps the helper private on both runtimes.
- **Exact-version resolver:** binds assembly references but does not hide the colliding public type
  from PowerShell. It also adds runtime loader policy and version coupling.
- **Own expression parser:** would require maintaining syntax, evaluation and compatibility instead
  of using the established Serilog language. The bounded Expressions package can be internalized safely.

## Consequences

- No Expressions types are public through Core or PowerShell type lookup. Exceptionless 1.0.0 must
  deliver through a filtered child logger whether its import precedes or follows filter compilation.
- Expressions still uses shared Serilog event/value types; sinks and the v2 extension contract remain shared.
- A new Expressions version needs a Core release. Upgrade the pinned version, review upstream licence/NOTICE
  changes and run unit, Pester (including PowerShell 7.4) and compatibility tests before releasing.
- Stack traces now identify expression implementation frames as PoShLog.Core rather than Serilog.Expressions.
  Core is larger and its build depends on ILRepack; there is no runtime merge or loader dependency.
- Ship the upstream Apache-2.0 text as `lib/Serilog.Expressions.LICENSE` and the copyright, provenance and
  modification notice in `lib/THIRD-PARTY-NOTICES.txt`. The notice describes IL merging and internalization;
  upstream source is unchanged. The pinned upstream revision has no NOTICE file. PoShLog's MIT licence does
  not replace the incorporated component's licence.
