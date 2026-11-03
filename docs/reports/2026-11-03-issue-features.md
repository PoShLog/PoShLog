# Issue features implementation report — 2026-11-03

Implemented all four requested issues on `codex/issue-features`, based on `55f3185`.
The manifest version/prerelease label is unchanged. No GitHub writes, pushes, tags,
publication or deployment were performed.

| Issue | Result | Feature commit | Decision |
|---|---|---|---|
| [#41](https://github.com/PoShLog/PoShLog/issues/41) | ✅ PowerShell-relative File paths, both formatter overloads, short form and PSDrives | `4922407` | [0026](../decisions/0026-powershell-file-paths.md) |
| [#37](https://github.com/PoShLog/PoShLog/issues/37) | ✅ `Add-SinkLogger -Filter`, background-thread evaluation and caller-owned child logger | `8cb6883` | [0027](../decisions/0027-conditional-sublogger-expressions.md) |
| [#39](https://github.com/PoShLog/PoShLog/issues/39) | ✅ `New-Logger -ConfigurationPath`, bounded Serilog JSON schema and loaded extensions | `51af631` | [0028](../decisions/0028-json-logger-configuration.md) |
| [#30](https://github.com/PoShLog/PoShLog/issues/30) | ✅ ANSI/System token themes through `New-ConsoleTheme` | `e857cf8` | [0029](../decisions/0029-custom-console-token-themes.md) |

All four ADRs have status **Proposed**, and their index is updated. Each feature
commit contains its unit tests, documentation, source help and Unreleased changelog entry.

## Verification

- Baseline: **349 .NET**, **91 Pester** tests passed.
- Final: **376 .NET** passed (+27), zero failed/skipped. Core: 219; OpenTelemetry: 24;
  Splunk: 34; Syslog: 54; Elastic: 45.
- Final Pester: **97 passed** (+6), zero failed/skipped, on both **PowerShell 7.6.9**
  and **7.4.22**. The full suite used `Invoke-Pester ./tests -PassThru` in fresh hosts.
- `dotnet build -c Release --no-restore`: zero warnings/errors after public-feed restore.
  `dotnet test` also passed; the machine's unrelated FileMove NuGet feed emitted NU1900
  vulnerability-feed warnings, so later checks used `--no-restore` after restoring with
  `build/nuget.config`.
- `website`: `npm ci` passed with zero reported vulnerabilities; `npm run build`
  built **109 pages**, including this report. A temporary Markdown page linking to a
  missing file made sync exit nonzero with `sync-docs: 1 broken link(s)`; the probe was
  removed and the build passed again.
- Initial feature regression run before implementation: **9 failed / 7 passed** across
  16 new cases. Failures included paths, conditional routing, JSON loading and theme
  construction. Validation-only cases already rejected the then-unknown parameters;
  later assertions check meaningful errors as well.
- Added concurrent .NET routing checks (100 accepted events), partial-configuration
  resource cleanup, real ANSI token output, a legacy helper-name regression and actual
  JSON-configured Seq/Http delivery to loopback listeners.
- Published compatibility after compiling a JSON expression: Http 1.0.1 and Seq 1.0.0
  delivered to loopback, Enrichers 1.0.0 enriched a file, EventLog 1.0.0 configured without
  source creation, and Exceptionless 1.0.0 delivered to loopback. All five passed.
  The temporary default-context Expressions implementation broke Exceptionless; an
  independently built `55f3185` baseline passed. The final isolated expression engine
  restores compatibility while sharing Serilog's event types with the host.

## Fresh-process examples

Run each [example](../../examples/issue-features) separately with `pwsh -NoProfile -File`.
All four passed on both tested PowerShell versions. Captured output follows;
`<ESC>` represents the ANSI escape character.

Relative path:

```text
Different process directory: True
Relative path works
```

Conditional sink:

```text
All events:
Selected true
Local only false
Selected events:
Selected true
```

JSON configuration:

```text
backup Configured from JSON
```

Console theme:

```text
User <ESC>[0m<ESC>[32mAda<ESC>[0m has <ESC>[0m<ESC>[36m3<ESC>[0m items<ESC>[0m
```

## Proposed issue replies (not posted)

### #41

Implemented for the next 3.0.0 preview (PowerShell 7.4+). `Add-SinkFile -Path` now
resolves relative paths against the current PowerShell FileSystem location, including
custom PSDrives. The same applies to short-form `Start-Logger -FilePath`; native
absolute paths remain unchanged. Use `Join-Path $PSScriptRoot 'logs/my.log'` when you
specifically want the caller's script directory. Regression tests cover both formatter
overloads and a process directory that differs from the PowerShell location.

### #37

Implemented for the next 3.0.0 preview as `Add-SinkLogger -Filter 'Send = true'`.
Build a sublogger with your Seq sink, then route matching events to it while the
parent's File sink retains all events. The filter uses Serilog expression syntax,
compiles during configuration and evaluates without a PowerShell runspace, including
on background threads. Dispose the child logger after closing the parent. See the
[conditional sink guide](../guides/conditional-sinks.md).

### #39

Implemented for the next 3.0.0 preview as `New-Logger -ConfigurationPath ./logging.json`.
It reads a supported subset of the Serilog JSON schema: minimum levels/overrides,
properties, sinks, enrichers and expression filters. File/Console work directly;
import extensions before using their public configuration methods with scalar arguments.
Complex options, formatter objects, switches and callbacks remain in the PowerShell
pipeline, and configuration is read once rather than hot-reloaded. The reader avoids
configuration-library conflicts with published extensions. See the
[JSON configuration guide](../guides/json-configuration.md).

### #30

Implemented for the next 3.0.0 preview with `New-ConsoleTheme`. For example,
`New-ConsoleTheme -Foreground @{ String = 'Green'; Number = 'Cyan' }` returns a theme
for `Add-SinkConsole -Theme`. This highlights structured string/number arguments
differently from the surrounding message text. ANSI sequences and System foreground/
background colors are supported per token type. Arbitrary substrings and individual
property names are outside this token-theme API; no escape codes are inserted into
the underlying events. See the [theme reference](../cmdlets/New-ConsoleTheme.md).

## Limits

No Linux/macOS run, production service delivery, full third-party compatibility matrix,
real Event Log write, or website deployment was performed. System theme mappings are
asserted in tests; physical terminal appearance was not visually reviewed. The JSON
reader deliberately supports the documented subset rather than the entire upstream
Settings.Configuration schema. No unsupported follow-up work was started.
