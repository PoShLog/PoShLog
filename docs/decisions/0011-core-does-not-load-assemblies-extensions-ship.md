# 0011 — Core does not load assemblies that published extensions ship

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Amends:** [0003](0003-keep-the-v2-extension-contract.md) ("a newer one satisfies older references")

## Context

ADR 0003 relies on .NET binding an extension's reference to an older Serilog to the newer one Core loaded. That holds
for references. It does not hold when an extension loads **the same assembly name itself**: v2-era extensions run
`Add-Type -Path` on every DLL in their `lib/`, and `Add-Type` fails with "Assembly with same name is already loaded"
when Core already loaded another version. Their load loop then stops and the sink never loads. Found by Senior Dev
on 2026-11-03: with Serilog.Formatting.Compact 3.0 loaded by Core, PoShLog.Sinks.Seq 1.0.0 (which ships its own
Serilog.Formatting.Compact) no longer works. ADR 0007 avoided it with Core's own CLEF formatter.

## Decision

Core loads only Serilog, Serilog.Sinks.File and Serilog.Sinks.Console, which no supported published extension ships
in its `lib/`. Core takes no new dependency on an assembly that a supported published extension ships; when it needs
such functionality, it implements it internally (as ADR 0007 did). The compatibility suite (Published and ThirdParty
modes) is the check.

## Alternatives considered

- **Load conflicting assemblies into a separate AssemblyLoadContext.** Rejected in ADR 0003: sinks must share
  Serilog's types with Core.
- **Ship a shim that makes `Add-Type` tolerate an already loaded name.** Changes how third-party modules load and
  cannot be done without overriding a built-in cmdlet.

## Consequences

- A new Core dependency starts with a check of the `lib/` folders of the published extensions listed in `tests/compat/README.md`.
- Some features cost more (an own formatter instead of a package).
