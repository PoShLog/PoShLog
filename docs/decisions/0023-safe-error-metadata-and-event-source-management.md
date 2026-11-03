# 0023 — Safe error invocation metadata and explicit Event Log source management

- **Status:** proposed
- **Date:** 2026-11-03

## Context

The command audit found that error enrichment retained argument values and source text, including under destructuring. Event Log source management converted the explicit boolean false to a nonempty string and had no confirmation boundary.

## Decision

Project invocation metadata onto scalar execution fields, retaining command names, script paths and line numbers while removing bound parameters, unbound arguments, source lines, display script positions and position messages. Do not provide raw argument capture; applications can add selected, reviewed properties explicitly. Keep Event Log's explicit-value syntax with a boolean defaulting to false, and call ShouldProcess before configuring source management.

## Alternatives considered

- Name-based redaction misses positional values, arbitrary parameter names and source text.
- An opt-in raw capture parameter creates another path to accidental disclosure; defer it until a concrete need exists.
- A switch for source management would break existing `-ManageEventSource $false` calls.
- Relying on OS permissions allows unintended source creation for elevated processes.

## Consequences

Previously emitted raw invocation fields disappear from text and structured enrichment. Error messages, exception details and target objects remain caller-provided; this projection does not sanitize arbitrary error content. Missing invocation metadata is represented as null. When source management is requested and WhatIf or confirmation declines it, return the original configuration without adding an Event Log sink. Existing-source configuration with management disabled needs no confirmation.
