# 0005 — Destructure PowerShell objects as PowerShell users see them

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03

## Context

`Write-InfoLog '{@Item}' -PropertyValues $obj` hands Serilog the value PowerShell passed, which is usually a
`PSObject`. Serilog does not know that type, so it reflects over its public properties: `BaseObject`, `Members`,
`Properties`, `Methods`, `TypeNames`, `ImmediateBaseObject`. Every `PSMemberInfo` in them has a `Value` that is
again a `PSObject`. The output grows with every level until Serilog's depth limit of 10 stops it, and logging a
`Select-Object` result with a calculated property produced megabytes of text or appeared to hang (issue #46).

Two more problems came with it:

- A hashtable is a non-generic `IDictionary`. Serilog only turns generic dictionaries into a `DictionaryValue`, so a
  hashtable came out as a list of `DictionaryEntry` structures (`[{"Key":…,"Value":…}]`).
- A cycle (`$a.Peer = $b; $b.Peer = $a`) was only stopped by the depth limit, after ten copies of each object.

The fix has to stay inside Core, keep the v2 extension contract (ADR 0003) and leave the rendering of
non-destructured values (`{Item}`, which logs the string form `@{B=1}`) as it was.

## Decision

**Start-Logger registers an `IDestructuringPolicy` (`PSObjectDestructuringPolicy`) on every logger configuration it
starts.** It applies only when Serilog destructures (`{@Name}`, `-Destructure` on `Push-LogContextProperty`):

- **`[pscustomobject]`** (also from `Select-Object`, `ConvertFrom-Json`, `Import-Csv`, `Add-Member`) becomes a
  structure of its PowerShell properties: note, alias, script and code properties, in their PowerShell order.
  **Dropped:** methods, the adapter members (`BaseObject`, `Members`, `TypeNames`, …), properties that cannot be read,
  names Serilog rejects, and a property whose getter throws (skipped, reported through SelfLog). No `$type` tag is
  written, because every such object would be tagged `PSCustomObject`.
- **Hashtables and other non-generic dictionaries** (also wrapped in a `PSObject`) become a dictionary keyed by their
  keys, so JSON output is an object. Keys wrapped in a `PSObject` are unwrapped.
- **Any other `PSObject`** is unwrapped, and its base object is destructured the way Serilog would destructure it on
  its own. A `FileInfo` or `ServiceController` keeps Serilog's normal output.
- **Cycles:** an object or dictionary that is already being destructured further up the same value is written as the
  string `"[Circular]"`. The same object twice side by side is not a cycle and is written twice.
- **Depth:** nested values go back through Serilog, so its maximum depth (10 by default) bounds everything. Users who
  want less set `$config.Destructure.ToMaximumDepth(n)` on the configuration from `New-Logger`.

## Alternatives considered

- **A `ToString()` of the object, or `ConvertTo-Json`.** It loses the structure that `{@…}` asks for, and
  `ConvertTo-Json` is slow, warns on depth and needs a runspace on the logging thread.
- **Fixing it in the `Write-*Log` cmdlets** (converting `-PropertyValues` before they reach Serilog). It would miss
  values that reach Serilog another way (`Push-LogContextProperty`, `Add-EnrichWithProperty`, a nested value in a
  dictionary), and the cmdlets cannot see which properties the template destructures.
- **Using PowerShell's adapted properties for every object** (`PSObject.AsPSObject($x).Properties`). That also turns a
  `FileInfo` into its ETS view, with script properties such as `VersionInfo` that run code on the logging path and are
  even larger. Leaving CLR objects to Serilog keeps the change small and predictable.
- **A lower default depth (for example 3).** It would cut legitimate nested structures in existing logs. The default
  stays Serilog's; the docs show how to lower it.
- **Throwing or dropping the whole value on a cycle.** It hides the rest of the object; the marker keeps the parts
  that are fine.

## Consequences

- `{@x}` on a PowerShell object now produces the JSON a PowerShell user expects, and the output for a hashtable
  changes from a list of entries to an object. That is a visible change in log files and goes into the CHANGELOG.
- Every logger started by `Start-Logger` carries the policy, including those built by extensions, because the policy
  is added to the configuration just before `CreateLogger()`. A logger created without `Start-Logger` (direct
  `CreateLogger()` calls) does not.
- CLR objects such as `Get-Item` output are still verbose (about 15 KB at depth 10). The usage guide recommends
  `Select-Object` or a lower depth.
- The cycle check uses a thread-static set, so it is safe for concurrent logging on different threads.
