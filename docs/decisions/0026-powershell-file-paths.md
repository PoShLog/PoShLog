# 0026 — Resolve file sink paths through the PowerShell provider

- **Status:** Proposed
- **Date:** 2026-11-03

## Context

Issue #41 reports relative file paths resolving outside the PowerShell location.
PowerShell's location can differ from the process current directory and can use PSDrives.

## Decision

Resolve File sink cmdlet paths with `SessionState.Path.GetUnresolvedProviderPathFromPSPath`
at configuration time, reject non-FileSystem providers, and preserve native absolute paths.
Share the resolver between `Add-SinkFile`, short-form `Start-Logger`, and configuration-file loading.

## Alternatives considered

- Changing the process directory affects unrelated code and other runspaces.
- Using the caller's script directory makes interactive use surprising; callers can pass `$PSScriptRoot` explicitly.
- Resolving existing paths would prevent creation of new log files.

## Consequences

Relative cmdlet paths follow PowerShell consistently, including custom PSDrives, without
global state changes. The core JSON File sink uses the same resolver. Extension buffer
arguments retain upstream semantics and should use absolute paths.
