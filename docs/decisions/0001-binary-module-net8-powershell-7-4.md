# 0001 — v3 is a binary module on net8.0 for PowerShell 7.4+

- **Status:** Superseded by [0033](0033-net10-powershell-7-6.md) (accepted by Tomáš 2026-11-03, superseded 2026-11-04)
- **Date:** 2026-11-03

## Context

PoShLog v2 is a script module that loads Serilog 2.10 through `Add-Type` and supports Windows PowerShell 5.1 and
PowerShell 7. The v3 branch (`tomasbouda-ci-pipeline-and-tests`, Jul 2026) rewrites it as a compiled C# binary
module on Serilog 4.2. It targets `net8.0` and declares `PowerShellVersion = '7.0'`.

A binary module can only load in a PowerShell whose runtime is at least its target framework. PowerShell 7.4 is the
first release on .NET 8; 7.0–7.3 ran on .NET Core 3.1/5/6/7 and cannot load a `net8.0` assembly. 7.4 LTS reaches end
of support in Nov 2026, but it is still common on servers. 7.6 LTS runs on .NET 10 and loads `net8.0` assemblies.
The global rule is `net10.0` unless there is a concrete external constraint.

## Decision

- Target **`net8.0`**: it is the lowest runtime among the PowerShell versions we support. This is the stated
  exception to the `net10.0` rule, so the module loads in PowerShell 7.4, 7.5 and 7.6.
- The manifest declares **`PowerShellVersion = '7.4'`**, `CompatiblePSEditions = 'Core'`, and drops the
  `PSEdition_Desktop` tag.
- **Windows PowerShell 5.1 is dropped in v3.** 5.1 users stay on the v2 line (see the plan for a final 2.2.0).
- Tests and CI keep building on the .NET 8 SDK and also run Pester under the newest PowerShell.

## Alternatives considered

- **`net10.0` / PowerShell 7.6+ only.** It follows the global rule, but it locks out every machine still on 7.4 or
  7.5 and gains nothing the module uses.
- **`netstandard2.0` for 5.1 and 7.** This is what v2 did. Serilog 4 still ships netstandard2.0, but 5.1 brings
  assembly-binding conflicts (no AssemblyLoadContext) and a second test matrix. That cost is what made v2 hard
  to maintain.
- **Keep `PowerShellVersion = '7.0'`.** The module installs on 7.0–7.3 and then fails to import with a loader
  error. A clear manifest error is better.

## Consequences

- When 7.4 and 7.5 are long gone, moving to a newer target is a new ADR that supersedes this one.
- Every PoShLog extension module (sinks, enrichers) must reference the same Serilog major version as Core. They are
  loaded into the same default AssemblyLoadContext.
