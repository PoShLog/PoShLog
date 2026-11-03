# 0009 — First-party sinks; other authors' sinks are a non-blocking check

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Amends:** [0003](0003-keep-the-v2-extension-contract.md) (which published extensions gate a release)

## Context

ADR 0003 made every published extension in ADR 0002, ours and other authors', a release gate. The first CI runs
showed the cost: PoShLog.Sinks.DataDog 0.1.1 cannot import on Linux with any PoShLog version (its manifest names
`PoShLog.Sinks.Datadog.psm1`), and modules we cannot fix would block our releases. Users of Splunk, Datadog, Syslog
and Elasticsearch also depend on modules whose maintenance we do not control.

## Decision

- The v2 extension contract stays in v3 unchanged (ADR 0003). We do not break it; we stop gating on other people's
  modules.
- The compatibility suite has three modes. **InRepo** (extensions built here) and **Published** (our own published
  extensions: Enrichers, Seq, EventLog, Http, Exceptionless) block CI and releases. **ThirdParty** (Syslog, DataDog,
  ElmahIo, Splunk) runs on every CI with `continue-on-error`; failures are annotated and gate nothing.
- We write **first-party sinks** in `extensions/` as thin wrappers over the official Serilog sinks, cross-platform,
  PowerShell 7.4+, built and released like Seq, EventLog and Http.

### Which sinks, and their names

The PowerShell Gallery names `PoShLog.Sinks.Splunk`, `.DataDog`, `.Syslog`, `.ElmahIo` and `.Elasticsearch` belong to
other authors, and Gallery IDs are case-insensitive. Rule: keep the `PoShLog.Sinks.` prefix of Seq, EventLog and
Http; use the product name when it is free, otherwise the product plus what the module speaks. Command names follow
the product (`Add-SinkSplunk`, ...), so scripts move over with a parameter review.

| Sink | Module | Serilog package | Verdict |
|---|---|---|---|
| Syslog | `PoShLog.Sinks.Syslog.Rfc5424` | Serilog.Sinks.Syslog | **Build.** Syslog has no OTLP; it is the default for network gear and Linux hosts. |
| Splunk | `PoShLog.Sinks.Splunk.Hec` | Serilog.Sinks.Splunk | **Build.** HEC works without an OTel Collector; the third-party module has ~112k downloads. |
| Elasticsearch | `PoShLog.Sinks.Elastic` | Elastic.Serilog.Sinks | **Build.** Writes data streams straight to Elasticsearch, without an APM server or collector. |
| Datadog | `PoShLog.Sinks.Datadog.Logs` | Serilog.Sinks.Datadog.Logs | **Later.** The Datadog Agent and Datadog's OTLP intake are reached by the OTLP sink; build only if users ask. |
| elmah.io | none | - | **Do not build.** elmah.io maintains its own module (4.0.4); duplicating a vendor module adds nothing. |

The names are checked for availability and confirmed by Tomáš before the first publish.

## Alternatives considered

- **Keep third-party modules as a release gate (ADR 0003 as written).** One broken manifest outside our control
  blocks every release.
- **Drop the third-party check.** We would no longer notice when v3 breaks somebody's sink; the contract would erode
  silently.
- **Ask the authors to transfer the Gallery names.** Slow and uncertain; contacting them is Tomáš's call and can
  still happen later.
- **A different prefix for the new family (`PoShLog.Extensions.*`).** Clear, but inconsistent with the three
  existing first-party sinks.

## Consequences

- `tests/compat` gains a `ThirdParty` mode; `compat.yml` runs it with `continue-on-error`; `release.yml` keeps
  depending on the compat job, which now fails only for InRepo and Published.
- The sinks page lists our modules next to the third-party ones and says which is maintained by whom.
- Each new sink is a TaskGraph task with its own brief; OTLP stays the recommended route for Datadog.
