# 0028 — Load a Serilog JSON configuration snapshot

- **Status:** Proposed
- **Date:** 2026-11-03

## Context

Issue #39 needs logging changes without script edits. The binary module has no application
dependency context, extensions load separately, and PowerShell 7.4 hosts .NET 8.

## Decision

Add `New-Logger -ConfigurationPath` with a bounded `System.Text.Json` reader for a
subset of the Serilog schema. Bind public configuration extension methods from loaded
assemblies using scalar arguments, plus built-in context enrichment. Permit subsequent
pipeline configuration for complex objects and callbacks.

## Alternatives considered

- Serilog.Settings.Configuration 8.0.4 brings Microsoft.Extensions.Configuration assemblies
  also shipped by published PoShLog.Sinks.Http 1.0.1, violating ADR 0011's rule against new
  dependencies owned by published extensions. Downloaded package inventory confirmed the
  overlap; Http uses a nested binary module with its own older configuration dependencies.
  Avoid introducing that version-binding risk rather than changing extension loading.
- Isolating the configuration stack in another AssemblyLoadContext complicates shared sink
  signatures that accept IConfiguration and module lifetime management.
- Application dependency discovery is unreliable in a binary PowerShell module.
- Automatic module import hides extension lifetime and dependency conflicts.
- Hot reload adds watchers and ownership obligations to a configuration object passed through a pipeline.
- Arbitrary object construction duplicates upstream binding and widens the trusted-input
  surface; support scalar method arguments and direct users to the pipeline for complex setup.

## Consequences

Core File and Console sinks work immediately; extensions must be imported first and
expose public Serilog configuration methods in the default load context with supported scalar arguments. `Using`
asserts that assemblies are loaded, without importing them. Minimum levels/overrides,
static properties, enrichment and expression filters are supported. Switch declarations,
audit sinks, destructuring setup, nested callbacks and typed formatter/theme objects stay
in the pipeline. Unknown or ambiguous methods and unsupported options fail explicitly.
Core File paths use PowerShell resolution. Configuration stays trusted input; no hot
reload or automatic type construction occurs. Only Serilog.Expressions is added as a
dependency; the inspected published extension inventories contain no such assembly.
The expression engine is isolated as described in ADR 0027, and PoShLog exposes
uniquely named JSON expression filter methods to preserve legacy sink type lookup.
The manifest version and prerelease label remain release concerns.
