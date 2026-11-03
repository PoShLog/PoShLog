# 0007 — Core writes CLEF with its own formatter

- **Status:** proposed
- **Date:** 2026-11-03

## Context

Issue #48 asks for the Compact Log Event Format (CLEF), the newline-delimited JSON that Seq and many log shippers
read. The usual way is the `Serilog.Formatting.Compact` package (`CompactJsonFormatter`,
`RenderedCompactJsonFormatter`).

Core loads its dependencies at import, into the default AssemblyLoadContext (ADR 0003). The published
**PoShLog.Sinks.Seq 1.0.0** extension ships its own, older `Serilog.Formatting.Compact.dll` and loads it with
`Add-Type -Path` in a loop. **Verified 2026-11-03:** when Core had already loaded `Serilog.Formatting.Compact` 3.0,
that `Add-Type` failed with "Assembly with same name is already loaded", the extension's loop stopped, and the Seq
sink assembly was never loaded. ADR 0003 assumes that a newer version in Core satisfies an older reference; that is
true for references resolved by the runtime, but not for an extension that `Add-Type`s a file of the same assembly
name itself.

## Decision

**Core ships its own `PoShLog.Core.Formatting.CompactJsonFormatter` and does not reference
`Serilog.Formatting.Compact`.** `Get-CompactFormatter` returns it; `-Rendered` switches it to the rendered variant.
The output is the same as the package's two formatters (`@t`, `@mt`/`@m`, `@r`, `@i`, `@l`, `@x`, `@tr`, `@sp`,
properties with a leading `@` doubled), and the event id uses the same Jenkins hash. The xUnit tests compare it
with the package, which is referenced by the test project only.

## Alternatives considered

- **Reference `Serilog.Formatting.Compact` 3.0 in Core.** It breaks the published Seq extension at import, as
  verified above, which ADR 0003 forbids.
- **Ship the same old version the Seq extension ships.** It pins Core to a 2019 package, and the next extension
  with yet another version would collide the same way.
- **Load the package into its own AssemblyLoadContext.** The formatter has to implement Serilog's `ITextFormatter`
  from the default context, so it cannot live in another context (the same reason ADR 0003 rejects ALC isolation).
- **Tell users to install the package themselves.** CLEF output for a file is a basic need, and users would hit the
  same load conflict once they also use the Seq extension.

## Consequences

- About 150 lines of formatter code to maintain. The comparison tests catch a drift from the reference package when
  either side changes.
- The load-order finding also applies to every other package Core might add: before Core ships a Serilog package,
  check that no known extension `Add-Type`s the same assembly. The compatibility suite (InRepo and published) is the
  check; ADR 0003's assumption should be narrowed in a follow-up record.
- Users who want the package's own type can still load it in their scripts, but not together with
  PoShLog.Sinks.Seq 1.0.0.
