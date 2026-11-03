# 0004 — Refreshed extensions require PoShLog 3

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Amends:** [0001](0001-binary-module-net8-powershell-7-4.md) (Serilog major rule),
  [0002](0002-sinks-and-enrichers-in-v3.md) (`RequiredModules` of refreshed modules)

## Context

ADR 0002 keeps `RequiredModules` of the refreshed Seq, EventLog, Http and Enrichers modules at PoShLog `2.0.0`,
"so one version serves both lines where possible". The refreshed modules (1.1.0, built in `extensions/`) target
net8.0 and reference Serilog 4.4 assemblies (Serilog.Sinks.Seq 9, Serilog.Sinks.Http 9).

Compatibility is directional:

- **Old extension on new Core** works: a reference to Serilog 2.0.0.0 binds to the loaded 4.x (ADR 0003, verified).
- **New extension on old Core** is not expected to work: PoShLog 2.x loads Serilog 2.x first, and a sink assembly
  compiled against Serilog 4.0.0.0 cannot bind to a lower loaded version. With `RequiredModules` at 2.0.0,
  `Update-Module` on a PoShLog 2.x machine running PowerShell 7 would install 1.1.0 and break the import.
  Not verified yet; the compatibility suite gets a case for it.

ADR 0001 also says every extension "must reference the same Serilog major version as Core". That is too strong:
published v2-era extensions reference Serilog 2 and keep working (ADR 0003).

## Decision

Extensions built from this repository declare `RequiredModules` PoShLog `3.0.0` (by GUID) and reference Serilog
assemblies no newer than the ones Core ships. ADR 0001's Serilog-major rule applies to these in-repo extensions
only; published third-party and v2-era extensions are governed by ADR 0003. Users who stay on PoShLog 2.x keep the
extension's 1.0.x version.

## Alternatives considered

- **Keep `RequiredModules` 2.0.0 (ADR 0002 as written).** One version for both lines, but on PowerShell 7 with
  PoShLog 2.x the update installs a module that fails to load, with an assembly error the user cannot place.
- **Build the refreshed extensions against Serilog 2.x.** Would load under both lines, but locks the sinks to
  package versions from 2021–2022 and gives up fixes and features (Seq payload formatter, Http batching).

## Consequences

- PowerShell Gallery resolves the dependency: installing a refreshed extension pulls PoShLog 3.0.0. Until 3.0.0 is
  stable, the refreshed extensions can only be published as prereleases.
- Each extension's README and CHANGELOG state "1.1.0 requires PoShLog 3; stay on 1.0.x with PoShLog 2".
- The compatibility suite adds a CI case that loads a refreshed extension with PoShLog 2.1.0 and expects the
  failure, so the reason for this rule stays visible.
