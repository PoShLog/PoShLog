# v2 or v3?

PoShLog has two maintained lines ([ADR 0010](decisions/0010-v2-maintenance-line.md)).

| | v2 | v3 |
|---|---|---|
| Runs on | Windows PowerShell 5.1 and PowerShell 7 | Repository builds support Windows PowerShell 5.1 (.NET Framework 4.7.2+) and PowerShell 7.6+ |
| Module type | Script module with a small netstandard2.0 helper library | Script loader and net472/net10.0 binary cmdlets |
| Serilog | 2.x | 4.x |
| Branch | `release/2.x` | `master` |
| Receives | Bug and security fixes | New features and sink modules |

## Which one should I use?

- **PowerShell 7.6 or newer:** use v3. While v3 is a preview, install it with `Install-Module PoShLog -AllowPrerelease`;
  without the switch you get 2.2.0.
- **PowerShell 7.4 or 7.5:** use v2, pinned as shown below, or move to PowerShell 7.6. Both reach end of support with .NET 8
  and 9 on 2026-11-10, and v3 releases after 3.0.0-preview3 need 7.6 ([ADR 0033](decisions/0033-net10-powershell-7-6.md)).
- **Windows PowerShell 5.1** supports Core phase 1 in repository builds. This support is unreleased. It includes
  core sinks, formatters, enrichment, switches, PSObject destructuring and non-expression JSON.
  Expressions and refreshed extensions require PowerShell 7.6+. See [compatibility](compatibility.md).
  Gallery users can keep v2 pinned until a Desktop-capable package ships.

  ```powershell
  Install-Module PoShLog -RequiredVersion 2.3.0
  Import-Module PoShLog -RequiredVersion 2.3.0
  ```

## Extension modules

- Extensions written for v2 (`PoShLog.Sinks.*` 1.0.x and third-party sinks) keep working on v3
  ([ADR 0003](decisions/0003-keep-the-v2-extension-contract.md)).
- Extensions refreshed for v3 are built on Serilog 4 and are not expected to load on v2. On v2, stay on the
  extension's 1.0.x version.
- PoShLog 2.x users stay on 1.0.x of PoShLog.Sinks.Seq, PoShLog.Sinks.EventLog, PoShLog.Sinks.Http and PoShLog.Enrichers; their 2.0.0 requires PoShLog 3.
- Which version works with which, and how to install the preview extensions: [compatibility page](compatibility.md).

## Moving from v2 to v3

On PowerShell 7.6+, use `Install-Module PoShLog -AllowPrerelease`. Desktop repository builds can be staged with
`./build/Build-Core.ps1` and `./build/Stage-Module.ps1 -Module PoShLog`. Import the staged manifest in a clean process.
Installed v2 and v3 can coexist. Their assemblies require separate processes. Scripts keep their commands. The
[migration guide](guides/migration-v3.md) lists the differences.
