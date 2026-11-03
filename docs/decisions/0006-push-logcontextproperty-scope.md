# 0006 — Push-LogContextProperty scopes with a script block or a bookmark

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03

## Context

`Add-EnrichFromLogContext` exists since v2, but PoShLog never shipped a cmdlet to put properties on the context;
users had to call `[Serilog.Context.LogContext]::PushProperty()` and keep the returned `IDisposable`. The v2 docs
mentioned a `Push-LogContextProp` that was never released (issue #34).

Serilog's `LogContext` is stored in an `AsyncLocal`. In PowerShell that means a pushed property lasts for the rest of
the pipeline invocation that pushed it: a script, a function call, one interactive prompt line. It does not survive
into the next `PowerShell.Invoke()` call, so a bookmark pushed on one prompt line is gone on the next one. A
PowerShell user also has no `using` statement to pop the property safely.

## Decision

**Add `Push-LogContextProperty` with two ways to end the scope:**

- **`-ScriptBlock`** (recommended): the properties apply while the block runs and are popped in a `finally`, also when
  it throws. The block runs in a child scope (like `& { }`), and its output is passed through.
- **Without a script block** the cmdlet returns the Serilog bookmark (`IDisposable`), to be disposed in `finally`.
  The docs state that it lasts only for the rest of the script or function that pushed it.

Parameters: `-Name`/`-Value` for one property, `-Property <IDictionary>` for several, `-Destructure` to log objects
with their structure (ADR 0005). A value PowerShell wrapped in a `PSObject` is unwrapped, so `6` stays a number.
The name is `Push-LogContextProperty`, not the abbreviated `Push-LogContextProp` from the v2 docs.

## Alternatives considered

- **Only the bookmark, like Serilog.** It works in scripts but silently does nothing on the next interactive prompt
  line, and forgetting `Dispose()` leaks the property into every later event of the script.
- **Only the script block.** It is the safest, but some scripts push context once at the top and log from many
  functions; forcing all of that into one block is awkward.
- **A module-level stack (`Push-`/`Pop-LogContextProperty` without a bookmark).** A global stack does not follow
  `AsyncLocal` flow, gets out of sync when a script throws between push and pop, and is wrong with
  `ForEach-Object -Parallel` and runspaces.
- **Running the script block in the caller's scope (dot-sourcing).** Variables assigned in the block would leak out;
  the child scope matches how `Invoke-Command`/`& {}` behave and keeps the scope obvious.
- **The short name `Push-LogContextProp`.** Abbreviated nouns go against the PowerShell naming guidelines, and the
  cmdlet was never published, so nobody depends on the short name.

## Consequences

- Properties only show up when the configuration has `Add-EnrichFromLogContext`; the cmdlet page says so.
- A bookmark pushed at an interactive prompt does not carry over to the next prompt line. This is documented, not
  worked around. Interactive behaviour across prompt lines was reasoned from the `AsyncLocal` semantics and the xUnit
  test with separate invocations, not tested in a real console.
- The new cmdlet is exported from the manifest (`CmdletsToExport`).
