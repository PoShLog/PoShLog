# 0010 — v2 stays a maintained line for Windows PowerShell 5.1

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Amends:** [0003](0003-keep-the-v2-extension-contract.md) ("a final 2.2.0 … for security and critical fixes only")
- **Note (2026-11-04):** v3 now requires PowerShell 7.6 ([0033](0033-net10-powershell-7-6.md), superseding 0001). v2 is
  also the line for PowerShell 7.4 and 7.5 users.

## Context

v3 requires PowerShell 7.4 (ADR 0001). Windows PowerShell 5.1 still runs on every Windows machine and in many
scheduled tasks and installers, and those users can only use v2. ADR 0003 planned a final 2.2.0 with security fixes
only. Tomáš wants v2 kept as a living line for them instead.

## Decision

- A long-lived branch **`release/2.x`**, created from `origin/dev` (2.2.0-preview1, 30 commits over master), is the v2
  line. `master` carries v3.
- **2.2.0** is released from it (issue #44). After that the line takes:
  - bug fixes;
  - Serilog updates that still load on .NET Framework 4.6.2+ (netstandard2.0 / net462 assets);
  - backports of v3 work when they are cheap and 5.1-compatible, first the PSObject destructuring (#46) and the
    console/transcript fixes (#45, #28).
- v2 stays what it is: a script module (about 40 functions) with its small netstandard2.0 helper DLL; it is not
  converted to a binary module (Tomáš, 2026-11-03).
- New features land in v3 first. v2 does not get new sink modules.
- The branch has its own CI on `windows-latest`, running Pester under both `powershell.exe` 5.1 and `pwsh` 7, and its
  own release workflow for 2.x.
- A docs page "v2 or v3" states the support policy: which PowerShell each line runs on, what each line receives, and
  how to pin (`Install-Module PoShLog -MaximumVersion 2.99`).

## Alternatives considered

- **Security fixes only (ADR 0003).** Less work, but 5.1 users would be left with known bugs that v3 already fixed.
- **Make v3 run on 5.1 (netstandard2.0 Core).** Gives up the net8 binary module (ADR 0001) and doubles the test
  matrix for every feature.
- **Maintain v2 on `dev`.** The name says nothing about the line, and v3 work would be tempted to land there.

## Consequences

- Two release lines to keep apart: CHANGELOG sections carry the line (`2.2.1`, `3.1.0`), and a fix in one is
  checked for the other.
- Extensions refreshed for v3 need PoShLog 3 (ADR 0004 if accepted); v2 users stay on the extensions' 1.0.x.
- Pushing the branch and publishing 2.x to the Gallery need Tomáš's yes.
