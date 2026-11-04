# 0027 — Filter sublogger routing with Serilog expressions

- **Status:** Superseded by [0032](0032-shade-serilog-expressions-into-core.md)
- **Date:** 2026-11-03
- **Amends:** [0011](0011-core-does-not-load-assemblies-extensions-ship.md) (Core now also loads Serilog.Expressions, isolated in its own load context)

## Context

Issue #37 needs property-based routing to one destination while other sinks retain all events.
`Add-SinkLogger` already accepts an existing logger. Serilog can emit on threads without a PowerShell runspace.

## Decision

Add an optional string `-Filter` to `Add-SinkLogger`, backed by Serilog.Expressions 5.0.0
and `WriteTo.Conditional`. Compile expressions at configuration time and evaluate them without PowerShell callbacks.
Load the expression engine in its own process-lifetime AssemblyLoadContext, sharing
Serilog's event/value types with the default context. Adapt its compiled delegate once.

## Alternatives considered

- Scriptblock predicates require runspace dispatch and introduce affinity, deadlock and lifetime problems.
- A global filter would incorrectly affect sibling sinks.
- A new conditional cmdlet duplicates the existing sublogger API.
- Loading Expressions into the default context introduces a public type named
  `Serilog.LoggerSinkConfigurationExtensions`, which shadows the helper used by published
  PoShLog.Sinks.Exceptionless 1.0.0. Its delivery passes on baseline 55f3185 and fails after
  default-context expression loading. Isolating only the expression engine preserves
  PowerShell lookup and does not isolate sinks or Serilog itself (ADR 0003).

## Consequences

Expressions can inspect event properties and levels on background threads. Users learn
Serilog expression syntax rather than PowerShell syntax. Non-true results exclude events;
invalid expressions fail immediately. Minimum-level gates and caller ownership of the
child logger remain unchanged.
PoShLog exposes its own uniquely named JSON filter methods over the isolated compiler.
The expression context lives for the process lifetime, like the binary module and Serilog;
configuration delegates do not require reflection during event evaluation.
