# v2 or v3?

PoShLog has two maintained lines ([ADR 0010](decisions/0010-v2-maintenance-line.md)).

| | v2 | v3 |
|---|---|---|
| Runs on | Windows PowerShell 5.1 and PowerShell 7 | PowerShell 7.6 and newer |
| Module type | Script module with a small netstandard2.0 helper library | Binary module (.NET 10) |
| Serilog | 2.x | 4.x |
| Branch | `release/2.x` | `master` |
| Receives | Bug fixes, Serilog updates that still load on .NET Framework, cheap backports of v3 fixes | All new features and new sink modules |

## Which one should I use?

- **PowerShell 7.6 or newer:** use v3. While v3 is a preview, install it with `Install-Module PoShLog -AllowPrerelease`;
  without the switch you get 2.2.0.
- **PowerShell 7.4 or 7.5:** use v2, pinned as shown below, or move to PowerShell 7.6. Both reach end of support with .NET 8
  and 9 on 2026-11-10, and v3 releases after 3.0.0-preview3 need 7.6 ([ADR 0033](decisions/0033-net10-powershell-7-6.md)).
- **Windows PowerShell 5.1** (scheduled tasks, installers, servers without PowerShell 7): use v2 and pin it, so that
  an update never pulls in v3:

  ```powershell
  Install-Module PoShLog -MaximumVersion 2.99
  Update-Module PoShLog -MaximumVersion 2.99
  ```

## Extension modules

- Extensions written for v2 (`PoShLog.Sinks.*` 1.0.x and third-party sinks) keep working on v3
  ([ADR 0003](decisions/0003-keep-the-v2-extension-contract.md)).
- Extensions refreshed for v3 are built on Serilog 4 and are not expected to load on v2. On v2, stay on the
  extension's 1.0.x version.
- PoShLog 2.x users stay on 1.0.x of PoShLog.Sinks.Seq, PoShLog.Sinks.EventLog, PoShLog.Sinks.Http and PoShLog.Enrichers; their 2.0.0 requires PoShLog 3.
- Which version works with which, and how to install the preview extensions: [compatibility page](compatibility.md).

## Moving from v2 to v3

Install PowerShell 7.6+, then `Install-Module PoShLog -AllowPrerelease` (v2 stays installed next to it). Scripts keep
their commands; the
[migration guide](guides/migration-v3.md) lists the differences.
