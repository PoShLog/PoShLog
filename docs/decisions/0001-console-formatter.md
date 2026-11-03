# 0001 - Console formatter parameter set

- Status: accepted
- Date: 2026-11-03

## Context

Issues #31 and #40 and discussion #38 request structured console output on the v2
script module, which must continue to support Windows PowerShell 5.1.

## Decision

Backport the v3 console formatter overload through a separate Formatter parameter
set with a mandatory ITextFormatter. Share the minimum level, level switch and
standard-error threshold. Keep OutputTemplate, FormatProvider and Theme in the
default text parameter set so incompatible formatting options fail at binding.
Keep the existing text overload and defaults unchanged.

## Alternatives considered

Accepting all formatting options together would silently ignore text options in
formatter mode. A separate JSON sink would duplicate Serilog's formatter API.

## Consequences

Get-JsonFormatter can be used directly with Add-SinkConsole. Console output still
bypasses PowerShell streams and transcript capture. Regression tests exercise
JSON properties, filtering, switches, stderr, text output and parameter binding.
