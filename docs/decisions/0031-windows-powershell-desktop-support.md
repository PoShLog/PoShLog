# 0031 — Support Windows PowerShell 5.1 with a bounded Desktop feature set

- **Status:** Proposed
- **Date:** 2026-11-04
- **Amends:** [0033](0033-net10-powershell-7-6.md), which superseded 0001
  (add a Desktop build without changing the PowerShell 7.6 floor for Core hosts),
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

- .NET Framework has no `AssemblyLoadContext`. On PowerShell 7 it isolated Serilog.Expressions for
  `Add-SinkLogger -Filter` (`ExpressionFilter`, ADR 0027; since ADR 0032 the engine is shaded into Core instead, which
  is the spike A route below) and it isolates the MSSqlServer worker (ADR 0030). AppDomain isolation would add a remoting
  boundary and cannot share `LoggerConfiguration` objects directly.
- Windows PowerShell 5.1 applies no binding redirects for module assemblies. Serilog and System.Text.Json pull in
  out-of-band packages on .NET Framework (System.Memory, System.Buffers, System.Runtime.CompilerServices.Unsafe,
  System.Diagnostics.DiagnosticSource and others). Az, PnP.PowerShell and PSFramework ship the same assemblies in other
  versions. This version unification, not the C# port, is the main risk.
- `JsonLoggerConfiguration` discovers configuration methods by filtering `AppDomain` assemblies through
  `AssemblyLoadContext.Default`; that filter has no Desktop equivalent.

Since ADR 0033 (2026-11-04) the Core build targets net10.0 and PowerShell 7.6+: PowerShell 7.4 and 7.5 reach end of
support with .NET 8 and 9 on 2026-11-10. The contributor raised the same point.

## Decision

Maintain one v3 source tree that builds **net472** and **net10.0** (`<TargetFrameworks>net472;net10.0</TargetFrameworks>`).

- The supported Desktop host is Windows PowerShell 5.1 on .NET Framework 4.7.2 or later (4.8/4.8.1 recommended).
  An actual 4.6.2 runtime is out of scope; supporting it needs its own runtime test and a new record. The contributor
  confirmed net472 over net462 (2026-11-04).
- net10.0 is the build for PowerShell 7.6+ (ADR 0033). net472 is a concrete external constraint on the global
  net10.0 default (Windows PowerShell runs only on .NET Framework) and is stated in the project files.

**Packaging.** Each target lives in its own folder (`lib/Desktop`, `lib/Core` or per-TFM names). The manifest declares
`CompatiblePSEditions = 'Desktop', 'Core'` and `PowerShellVersion = '5.1'`. Its `RootModule` becomes a small script
loader, `PoShLog.psm1`, compatible with 5.1 (Tomáš, 2026-11-05; the manifest switch is rejected under Alternatives).
PoShLog 2.x also has a script `RootModule`, but it loads one `lib` folder without an edition check. The precedent for
selecting a build by `$PSEdition` is the `.psm1` of EventLog 1.0.1. The loader:

- selects the build by `$PSEdition`;
- checks the .NET Framework floor on Desktop;
- rejects Core hosts older than 7.6 with a clear message;
- imports the selected binary module and re-exports exactly its commands, aliases and the existing exports;
- never loads assemblies from both folders.

PowerShell references are compile-only and per target: `Microsoft.PowerShell.5.1.ReferenceAssemblies` for net472 and
System.Management.Automation 7.6 (`Microsoft.PowerShell.SDK` 7.6.x, as on master) for net10.0. Not
PowerShellStandard.Library. The package never ships System.Management.Automation.

**Assembly resolution on Desktop.**

- One Serilog identity and the `LoggerConfiguration` pipeline contract (ADR 0003) are preserved.
- No changes to `powershell.exe.config`, the GAC or machine-wide binding policy.
- No global binding redirects and no "first DLL wins" resolver.
- The loader registers one `AssemblyResolve` handler. It is compiled code in Core's Desktop build, not a script block.
  It answers only for the assemblies Core owns and shares: Serilog, Serilog.Sinks.File, Serilog.Sinks.Console and the
  out-of-band System.* packages Core ships on Desktop (Tomáš, 2026-11-04).
  - For such a name it returns the copy already loaded from Core's Desktop folder, or loads that copy, and only when
    that copy's version is greater than or equal to the requested version.
  - Every other request and every lower version stays unresolved. The handler never substitutes another module's
    assembly, so there is still no "first DLL wins".
  - This is what lets the published v2-era extensions (1.x Seq, Http, Enrichers, EventLog, Exceptionless and others)
    run with v3 Core on Desktop. On .NET Framework a strong-named reference to an older Serilog does not roll forward to
    the loaded Serilog 4 the way it does on .NET.
- After the guards and the handler registration, the loader loads Serilog, Serilog.Sinks.File and
  Serilog.Sinks.Console from Core's folder on both hosts, then imports Core's binary module. This replaces the
  `RequiredAssemblies` preload that extensions rely on, without loading anything before the guards run.
- Core owns the shared out-of-band System.* packages on Desktop. Desktop extension builds do not ship their own copies
  (in the spirit of ADR 0011).
- **Loader guards.** The loader stops with a clear error, before it loads any Core assembly, when:
  - PoShLog 2.x is already loaded in the session;
  - another module has already loaded a Serilog older than Core's.

**Desktop feature set, phase 1.**

- Included: core logging, the console, file and PowerShell sinks, formatters, enrichment, level switches,
  `Write-*Log`, PSObject destructuring, and JSON configuration for the non-expression subset. JSON configuration uses
  a pinned System.Text.Json and a Desktop-specific assembly discovery.
- Not supported: expression filters (`Add-SinkLogger -Filter`, expression-based JSON `Filter` entries). On Desktop
  they fail with a clear "not supported on Windows PowerShell" error and never load Serilog.Expressions into the shared
  AppDomain.
- MSSqlServer stays PowerShell 7.6+ only and keeps its private `AssemblyLoadContext`. A Desktop SQL implementation
  needs a separate design and decision (see phase 2).
- Core goes first. Enrichers, Seq, EventLog, Splunk.Hec and Http follow once Core loads cleanly, each after its own
  Desktop runtime tests pass. Elastic, OpenTelemetry (HTTP/protobuf only; no gRPC claim) and Syslog (needs a tested
  Framework implementation of connection timeouts, TLS validation and transport disposal) come later.
- The extension catalog (ADR 0021) and the docs mark which extensions support Desktop. An extension's manifest adds
  `Desktop` only when its Desktop build ships.

**Own code before isolation** (Tomáš, 2026-11-04). When a dependency would risk assembly collisions on Desktop, first
evaluate replacing that piece with PoShLog's own code on inbox .NET Framework APIs or on assemblies Core already
shares. Small code of our own cannot conflict, and isolation without an `AssemblyLoadContext` is fragile. Isolating or
shading the dependency comes second, and the record for that feature says why our own code was not enough.

**Desktop feature set, phase 2 (routes under validation).** Each feature below gets its own ADR after its spike. Until
that ADR is accepted, the phase 1 "not supported" error stays.

- **`Add-SinkLogger -Filter` (spike A).** Preferred route: shade Serilog.Expressions into a PoShLog assembly with
  ILRepack `/internalize`, so that its public types disappear. Its public `Serilog.LoggerSinkConfigurationExtensions`
  would otherwise shadow the type of the same name in Exceptionless 1.0.0, which is why it is isolated today
  (ADR 0027). Fallback: an exact-version resolver that answers only for the Serilog.Expressions build PoShLog ships.
- **MSSqlServer (spike B).** Preferred route: PoShLog's own Desktop sink on the inbox `System.Data.SqlClient`. It
  writes with `SqlBulkCopy` through Serilog batching and authenticates with a SQL login, Windows integrated security
  or an AccessToken. Fallback: an out-of-process worker. Shading Microsoft.Data.SqlClient is rejected: it brings about
  60 assemblies and a native SNI.

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
- The `powershell.exe` job also runs the Published compat suite (`tests/compat`) with the published 1.x extensions in
  both import orders, plus the two loader guard cases (PoShLog 2.x loaded first, an older Serilog loaded first).
- The modern suite, the PowerShell 7.6 minimum-host check and the later PowerShell versions stay green.
- Each target's resolved transitive packages are recorded, and the shipping files are inspected. Compilation alone
  does not establish support.

## Alternatives considered

- **net462 + net10.0:** plausible, but it adds a legacy runtime commitment and .NET Standard consumption risk without a
  demonstrated need; the contributor also prefers net472.
- **netstandard2.0 only:** cannot hold the current modern isolation design in the same assembly and does not remove
  Desktop testing.
- **net472 + net8.0:** the first version of this record, kept for PowerShell 7.4 and 7.5. ADR 0033 moved Core to
  net10.0 because those hosts and .NET 8 leave support on 2026-11-10.
- **PowerShellStandard.Library as the one PowerShell reference:** a single package for both targets, but it fixes the
  API at the PowerShell Standard 5.1 surface for the net10.0 build too. Per-target reference assemblies keep each
  build honest about its host.
- **A manifest edition switch** (`RootModule = if ($PSEdition -ne 'Desktop') { ... } else { ... }`): it works. With a
  script-module fixture on 5.1.26100 and 7.6.9, `Import-Module`, `Test-ModuleManifest` and `Get-Module -ListAvailable`
  pass, and `Publish-PSResource` and `Save-PSResource` to a local repository pass on 7.6. The PowerShell Gallery and a
  real DLL `RootModule` were not tested. It is rejected for two reasons:
  - The guards must run before any Core assembly loads. A manifest would need `ScriptsToProcess` for that, which
    splits the loader's job across two places.
  - An `if` makes the manifest unreadable as data. `Import-PowerShellDataFile` fails on it on both editions, and
    `release.yml`, `build/Test-PackageInstall.ps1` and the tests read `PoShLog.psd1` that way. `SafeGetValue` throws on
    it too, and `ExtensionCatalog.ReadManifest` reads the embedded `PoShLog.psd1` with it for `Get-PoShLogExtension`.
- **Load Expressions and the SQL dependencies into the shared AppDomain:** gives up the existing coexistence
  protections.
- **Global binding redirects or a permissive resolver:** changes behaviour for other modules in the same process.
- **AppDomain or separate-process workers:** possible later designs, but they need a different boundary, lifecycle and
  performance assessment.
- **Keep v3 modern-only indefinitely:** the cheapest option, but it keeps two source lines alive.

## Consequences

- **Transcripts differ on Windows PowerShell 5.1.** The host's transcript records suppressed information events and
  leaves out the Error and Fatal events that the PowerShell sink displays, so ADR 0008's agreement between console and
  transcript holds only on PowerShell 7.6+. A v2 build shows the same on 5.1.26100, so this is no regression. Phase 1
  documents it with the `6>&1 | Out-Host` workaround and the shared suite tests the behaviour on each host.
- One source tree serves both editions, but the first Desktop release has explicit feature limits. Docs and release
  notes do not advertise full parity or promise coexistence with arbitrary third-party assembly versions.
- ADR 0003's assumption that a newer Serilog satisfies older references holds on PowerShell 7 (.NET) only. On Desktop
  it is provided by the resolver above and by nothing else.
- **Upgrade path.** Once a stable v3 supports Desktop, `Update-Module PoShLog` moves Windows PowerShell users from 2.3
  to v3 together with its breaking changes. That release needs:
  - a migration guide;
  - a CHANGELOG entry that announces Desktop support as a major change;
  - documentation of pinning v2 with `-RequiredVersion 2.3.0`.
- The packaging and the manifest change shape (a script loader as `RootModule`). The release and integration
  workflows must stage and test both folders.
- After this decision is accepted, `release/2.x` takes bug and security fixes only. Its current baseline is 2.3.0.
  This narrows ADR 0010 (no more feature backports).
- **v2 retirement is proposed, not promised.** The candidate date is 2027-06-30, and no earlier than six months after
  a stable Desktop-capable v3 release. It needs a separate decision once migration coverage is confirmed, and is
  postponed if required v2 scenarios remain uncovered. Existing history and published packages stay.
- Accepting a contributor's implementation PR does not retire v2, publish packages or change external repositories.
