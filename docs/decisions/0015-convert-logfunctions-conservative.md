# 0015 — Convert-LogFunctions is a conservative, reviewable helper

- **Status:** proposed
- **Date:** 2026-11-03

## Context

The preview2 onboarding review found that Convert-LogFunctions replaced text inside strings and comments,
changed Write-Error semantics, and overwrote scripts without a backup. Replacing an error-stream command with
logging changes `$?`, terminating errors and try/catch behavior. A helper cannot promise a safe migration by
renaming commands alone.

## Decision

- Keep the helper optional and outside the recommended migration path.
- Parse each file with `Parser.ParseFile`; refuse the entire file on parse errors.
- Rewrite only CommandAst command-name extents for Write-Verbose, Write-Debug, Write-Information,
  Write-Warning and simple Write-Host calls. Resolve parameters against built-in metadata, accepting
  unambiguous prefixes and mapping the message parameter to MessageTemplate.
- Never convert Write-Error. Report every recognized call with File, Line, Command, Action, Before, After and
  Reason. Skip unsupported parameters, splatting, pipeline input and other uncertain argument forms.
- Support ShouldProcess. WhatIf provides the proposed diff and writes nothing. Declined findings are Skipped.
- Copy the original to `<file>.bak` before writing; require Force to replace an existing backup. Preserve
  encoding, BOM and line endings. Reject invalid input and a file changed during inspection/confirmation.
- Accept Path with FullName pipeline property binding and retain FilePath as an alias.
- Keep the existing current-PowerShell CI jobs, add a PowerShell 7.4 Pester leg on Ubuntu and a macOS smoke
  leg that checks module import and a rendered structured event in a file.

## Alternatives considered

- **Continue string replacement.** It cannot distinguish executable commands from script data.
- **Convert Write-Error with a warning.** A warning cannot preserve error semantics; leave the call untouched.
- **Attempt a complete semantic migration.** Function shadowing, stream preferences, host formatting and
  message-template braces require human decisions. The helper reports a narrow syntactic diff instead.
- **Remove the helper.** Retaining a conservative optional tool helps users review simple scripts without
  positioning it as the migration path.

## Consequences

- Users must review the diff, configure logging themselves and keep the backup until tests pass.
- Some valid calls are deliberately skipped. The output explains why manual migration is needed.
- Unit tests cover literal text, skipped calls, ShouldProcess, backups, encoding and parse refusal.
- CI checks both the manifest minimum runtime and the current runtime, plus a short macOS smoke test.
