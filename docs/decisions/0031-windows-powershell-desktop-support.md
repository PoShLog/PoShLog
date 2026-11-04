# 0031 — Support Windows PowerShell 5.1 with a bounded Desktop feature set

- **Status:** Proposed
- **Date:** 2026-11-04
- **Amends:** [0001](0001-binary-module-net8-powershell-7-4.md)
  (add a Desktop build without changing the PowerShell 7.4 floor for Core hosts),
  [0003](0003-keep-the-v2-extension-contract.md)
  (define the Desktop compatibility boundary),
  [0010](0010-v2-maintenance-line.md)
  (v2 becomes bugfix-only once this decision is accepted).
- **Related:** [0011](0011-core-does-not-load-assemblies-extensions-ship.md),
  [0021](0021-extension-catalog-in-core.md),
  [0027](0027-conditional-sublogger-expressions.md),
  [0028](0028-json-logger-configuration.md),
  [0030](0030-mssqlserver-private-dependencies.md).

## Context

PoShLog 3.0.0-preview3 is a net8.0 binary module for PowerShell 7.4+ (`CompatiblePSEditions = 'Core'`,
`PowerShellVersion = '7.4'`, `RootModule = 'lib/PoShLog.Core.dll'`); every first-party extension manifest says the
same. Windows PowerShell 5.1 users use the separate 2.x script module (ADR 0010). A community contributor offered to
dual-target v3 for Windows PowerShell 5.1, and Tomáš accepted. The work happens on
`feature/windows-powershell-5.1` and reaches `master` only through review against this record.

Serilog 4.4.0 and the current first-party sink dependencies ship .NET Framework or .NET Standard 2.0 assets, so the
target frameworks do not prevent a Desktop build. An in-memory compile of Core against net462 reported 18 errors in
8 files, all language or BCL gaps. Available assets do not prove safe binding in a shared Windows PowerShell process,
though:

- .NET Framework has no `AssemblyLoadContext`. Today it isolates Serilog.Expressions for `Add-SinkLogger -Filter`
  (`ExpressionFilter`, ADR 0027) and the MSSqlServer worker (ADR 0030). AppDomain isolation would add a remoting
  boundary and cannot share `LoggerConfiguration` objects directly.
- Windows PowerShell 5.1 applies no binding redirects for module assemblies. Serilog and System.Text.Json pull in
  out-of-band packages on .NET Framework (System.Memory, System.Buffers, System.Runtime.CompilerServices.Unsafe,
  System.Diagnostics.DiagnosticSource and others). Az, PnP.PowerShell and PSFramework ship the same assemblies in other
  versions. This version unification, not the C# port, is the main risk.
- `JsonLoggerConfiguration` discovers configuration methods by filtering `AppDomain` assemblies through
  `AssemblyLoadContext.Default`; that filter has no Desktop equivalent.

PowerShell 7.4, 7.5 and 7.6 run on .NET 8, 9 and 10. Replacing net8.0 with net10.0 would exclude supported hosts.

## Decision

Maintain one v3 source tree that builds **net472** and **net8.0**.

- The supported Desktop host is Windows PowerShell 5.1 on .NET Framework 4.7.2 or later (4.8/4.8.1 recommended).
  An actual 4.6.2 runtime is out of scope; supporting it needs its own runtime test and a new record.
- net8.0 stays the build for PowerShell 7.4+. Both targets are concrete external constraints on the global net10.0
  default and are stated in the project files.

**Packaging.** Each target lives in its own folder (`lib/Desktop`, `lib/Core` or per-TFM names). The manifest declares
`CompatiblePSEditions = 'Desktop', 'Core'` and `PowerShellVersion = '5.1'`; its `RootModule` becomes a small
script loader compatible with 5.1, following the EventLog 1.0.x edition loader. The loader:

- selects the build by `$PSEdition`;
- checks the .NET Framework floor on Desktop;
- rejects Core hosts older than 7.4 with a clear message;
- imports the selected binary module and re-exports exactly its commands, aliases and the existing exports;
- never loads assemblies from both folders.

PowerShell references are compile-only for each target. The package never ships System.Management.Automation.

**Assembly resolution on Desktop.**

- One Serilog identity and the `LoggerConfiguration` pipeline contract (ADR 0003) are preserved.
- No changes to `powershell.exe.config`, the GAC or machine-wide binding policy.
- No global binding redirects and no "first DLL wins" resolver.
- An `AssemblyResolve` handler, if one is needed, answers only for assembly names that PoShLog ships in its own
  Desktop folder, and only with a version at least as high as the one requested. It must not substitute another
  module's assembly or a lower version.
- Core owns the shared out-of-band System.* packages on Desktop. Desktop extension builds do not ship their own copies
  (in the spirit of ADR 0011).

**Desktop feature set, phase 1.**

- Included: core logging, the console, file and PowerShell sinks, formatters, enrichment, level switches,
  `Write-*Log`, PSObject destructuring, and JSON configuration for the non-expression subset. JSON configuration uses
  a pinned System.Text.Json and a Desktop-specific assembly discovery.
- Not supported: expression filters (`Add-SinkLogger -Filter`, expression-based JSON `Filter` entries). On Desktop
  they fail with a clear "not supported on Windows PowerShell" error and never load Serilog.Expressions into the shared
  AppDomain.
- MSSqlServer stays PowerShell 7.4+ only and keeps its private `AssemblyLoadContext`. A Desktop SQL implementation
  needs a separate design and decision.
- Core goes first. Enrichers, Seq, EventLog, Splunk.Hec and Http follow once Core loads cleanly, each after its own
  Desktop runtime tests pass. Elastic, OpenTelemetry (HTTP/protobuf only; no gRPC claim) and Syslog (needs a tested
  Framework implementation of connection timeouts, TLS validation and transport disposal) come later.
- The extension catalog (ADR 0021) and the docs mark which extensions support Desktop. An extension's manifest adds
  `Desktop` only when its Desktop build ships.

Polyfills (for example Meziantou.Polyfill or small helpers) are allowed only for demonstrated gaps, pinned, and
preferably compile-time only. They do not replace runtime isolation or coexistence tests.

## Verification

- CI runs a **blocking** job on every pull request (to `master` and to `feature/windows-powershell-5.1`). It builds
  both targets, stages the v3 Desktop package and runs the shared Pester suite under real `powershell.exe`, not only
  the published v2.
- Required checks: command exports, logging streams, transcript behaviour, paths, PSObject destructuring, disposal
  and flush, JSON configuration, delivery for every Desktop-supported extension, and the explicit rejection of
  unsupported features.
- Clean-process import-order tests run both orders (PoShLog first and other module first) with the other first-party
  extensions and with pinned versions of Az, PnP.PowerShell and PSFramework. A synthetic DI fixture does not replace
  them.
- The modern suite, the PowerShell 7.4 minimum-host check and the later PowerShell versions stay green.
- Each target's resolved transitive packages are recorded, and the shipping files are inspected. Compilation alone
  does not establish support.

## Alternatives considered

- **net462 + net8.0:** plausible, but it adds a legacy runtime commitment and .NET Standard consumption risk without a
  demonstrated need.
- **netstandard2.0 only:** cannot hold the current modern isolation design in the same assembly and does not remove
  Desktop testing.
- **net472 + net10.0:** excludes PowerShell 7.4 and 7.5.
- **Load Expressions and the SQL dependencies into the shared AppDomain:** gives up the existing coexistence
  protections.
- **Global binding redirects or a permissive resolver:** changes behaviour for other modules in the same process.
- **AppDomain or separate-process workers:** possible later designs, but they need a different boundary, lifecycle and
  performance assessment.
- **Keep v3 modern-only indefinitely:** the cheapest option, but it keeps two source lines alive.

## Consequences

- One source tree serves both editions, but the first Desktop release has explicit feature limits. Docs and release
  notes do not advertise full parity or promise coexistence with arbitrary third-party assembly versions.
- The packaging and the manifest change shape (a script loader as `RootModule`). The release and integration
  workflows must stage and test both folders.
- After this decision is accepted, `release/2.x` takes bug and security fixes only. Its current baseline is 2.3.0.
  This narrows ADR 0010 (no more feature backports).
- **v2 retirement is proposed, not promised.** The candidate date is 2027-06-30, and no earlier than six months after
  a stable Desktop-capable v3 release. It needs a separate decision once migration coverage is confirmed, and is
  postponed if required v2 scenarios remain uncovered. Existing history and published packages stay.
- Accepting a contributor's implementation PR does not retire v2, publish packages or change external repositories.
