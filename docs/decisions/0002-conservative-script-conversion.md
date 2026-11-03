# 0002 - Conservative script conversion

- Status: accepted
- Date: 2026-11-03

## Context

The v2 Convert-LogFunctions helper globally replaced text, including strings and
comments, changed Write-Error semantics and overwrote input without a backup.
The v3 decision 0016 defines a conservative, reviewable replacement. The v2
implementation must remain a script function compatible with PowerShell 5.1.

## Decision

Port the v3 safety rules using System.Management.Automation.Language ASTs:

- Decode strictly, detect Unicode BOMs, and parse that exact text with ParseInput.
  This intentionally avoids ParseFile's platform-dependent BOM-less decoding on
  Windows PowerShell 5.1. Refuse parse errors and invalid encoding before writing.
- Plan edits only to recognized command names and supported parameter names.
  Resolve built-in parameter metadata, aliases and unambiguous prefixes; map the
  message argument to MessageTemplate. Never change Write-Error or string content.
- Skip uncertain forms, including unsupported parameters, splatting, incoming
  pipelines, redirections, invocation operators and multiple message arguments.
- Return File, Line, Command, Action, Before, After and Reason for each recognized
  call. Apply edits in reverse offset order to preserve unrelated text.
- Gate all writes with ShouldProcess. WhatIf returns the proposed changes without
  writing. Preserve the FilePath parameter and add Path/FullName aliases and
  pipeline property binding.
- Recheck original bytes after confirmation, copy the original to .bak, require
  Force to overwrite an existing backup, and atomically replace the input using a
  temporary sibling file and File.Replace (available on .NET Framework).
- Preserve the original BOM bytes, encoding and newlines. BOM-less files must be
  valid UTF-8; refuse invalid input instead of guessing a legacy code page.

## Alternatives considered

Regex replacement cannot distinguish executable commands from script data.
Converting Write-Error with a warning cannot preserve PowerShell error handling.
A full semantic migration would require resolving function shadowing, preferences
and message-template meaning; these remain a manual review responsibility.

## Consequences

The helper is optional and conservative. Users must review the diff and test the
script before relying on it. Backups are byte-for-byte originals. Regression
tests cover literal text, supported and skipped calls, pipeline paths, ShouldProcess
WhatIf, explicit Confirm suppression, backups, invalid input and six Unicode
encoding/BOM variants under Windows PowerShell 5.1 and PowerShell 7.
