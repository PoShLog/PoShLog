# 0029 — Build custom Serilog console token themes

- **Status:** Proposed
- **Date:** 2026-11-03

## Context

Issue #30 asks to highlight variable content within a log line. `Add-SinkConsole -Theme`
already supports Serilog themes, but constructing typed dictionaries from PowerShell is cumbersome.

## Decision

Add `New-ConsoleTheme` with mutually exclusive ANSI style and System color parameter
sets, accepting hashtables keyed by Serilog token names. Expose Console's existing
`applyThemeToRedirectedOutput` option for ANSI consumers and reproducible output checks.

## Alternatives considered

- Inserting escape codes into message values contaminates file and structured destinations.
- Coloring arbitrary substrings or property names requires a separate formatter and policy;
  defer that until a concrete need exceeds token themes.
- Replacing Serilog's theme engine duplicates existing token rendering and reset behavior.

## Consequences

String and numeric arguments can differ from surrounding text with no event mutation.
Missing styles are uncolored; style and color names are validated, and input tables are
copied. ANSI requires terminal support; System colors require console APIs. Formatter
overloads retain their own formatting and do not consume the theme.
