# 0035 — Expression filters on Windows PowerShell 5.1

- **Status:** accepted
- **Date:** 2026-11-18
- **Supersedes:** the phase 1 "not supported" statement for expression filters in [0031](0031-windows-powershell-desktop-support.md) (Desktop feature set, phase 1) and its spike A plan under phase 2.
- **Related:** [0027](0027-conditional-sublogger-expressions.md), [0032](0032-shade-serilog-expressions-into-core.md).

## Context

ADR 0031 left `Add-SinkLogger -Filter` and expression-based JSON `Filter` entries unsupported on Desktop until a spike showed a safe route. ADR 0032 has since shaded Serilog.Expressions 5.0.0 into `PoShLog.Core.dll` on net10.0 with ILRepack `/internalize`, so no standalone assembly or public type reaches the session. That is exactly the preferred route of spike A.

Serilog.Expressions 5.0.0 ships `net462` and `net471` builds whose only dependency is Serilog 4.0.0, which Core already shares. The Desktop collision risk named in ADR 0027 (a public `Serilog.LoggerSinkConfigurationExtensions` shadowing the type in Exceptionless 1.0.0) disappears once the types are internal.

ADR 0031 requires own code before isolation. A Serilog expression language (parser, binder, function library, null semantics) is far too large and too security-relevant to reimplement, and an own subset would drift from the documented language. Shading is the second step in that order, and its reason is recorded here.

## Decision

Build the Desktop target with the same ILRepack step as net10.0: merge the original compiler output with `Serilog.Expressions` (net471 build), internalize it, and ship no `Serilog.Expressions.dll`. `ExpressionFilter` and the JSON `Filter` reader lose their `NETFRAMEWORK` branches. Semantics, errors and types are the same on both editions.

The ILRepack targets run per target framework (not in the outer cross-targeting build), for both `net472` and `net10.0`.

## Consequences

- Desktop gets conditional sub-loggers and JSON filters; the "not supported on Windows PowerShell" error is gone.
- The Desktop assembly resolver, the load context rules and the no-standalone-assembly checks (`Build-Core.ps1`, `Stage-Module.ps1`) stay unchanged and now cover both builds.
- A new Expressions version needs a Core release, as already stated in ADR 0032.
- The support promise widens; Tomáš accepted it on 2026-11-23.

## Alternatives considered

- **Own expression subset:** rejected, see Context.
- **Exact-version resolver loading a standalone Serilog.Expressions.dll** (spike A fallback): leaves public types in the shared AppDomain and keeps the Exceptionless clash.
- **Keep it unsupported:** contradicts the goal of one feature set across editions.
