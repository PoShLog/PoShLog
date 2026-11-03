# 0013 — The Splunk HEC sink: compiled cmdlet, own batching, migration aliases

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Builds on:** [0009](0009-first-party-sinks-third-party-check-non-blocking.md) (name and scope),
  [0011](0011-core-does-not-load-assemblies-extensions-ship.md), [0012](0012-otlp-sink-design.md) (module layout)

## Context

ADR 0009 calls for a first-party Splunk HTTP Event Collector sink, `PoShLog.Sinks.Splunk.Hec`, with the command name
`Add-SinkSplunk`. Most Splunk users of PoShLog today use the third-party PoShLog.Sinks.Splunk 1.0.4 (about 112k
downloads). It is a script wrapper over Serilog.Sinks.Splunk 3.7.0, with the parameters `-SplunkHost`,
`-EventCollectorToken`, `-BatchIntervalSeconds` and `-HostName`.

Serilog.Sinks.Splunk 5.2.0, the current package, constrains the design:

- `WriteTo.EventCollector` takes the batch interval in whole seconds.
- It passes no queue limit to Serilog's batching, so the queue is unbounded.
- Its overload that takes a custom formatter has no source, sourcetype, index or host.
- The raw endpoint (`services/collector/raw`) needs that metadata in the query string, because a raw body has no
  envelope.
- The package appends the path to the host unless the host's path already contains `services/collector`.
- It writes an unterminated `"fields"` object for an empty custom field list.
- It drops a batch on 400, 403 and 405 and retries other failures.

Both modules use the command `Add-SinkSplunk`, and the two package versions cannot load into one process.

## Decision

`Add-SinkSplunk` is a compiled cmdlet, following the OTLP sink's layout (ADR 0012): `Dependencies.csproj`, a
version-aware psm1, and no Serilog.dll in `lib/`.

- **Sink construction.** The cmdlet builds `EventCollectorSink` and `BatchingOptions` itself, so that:
  - `-BatchInterval` is a TimeSpan, and a bare number means seconds;
  - `-QueueLimit` defaults to 100000;
  - `-Endpoint Raw` gets a text formatter and a query string built by `SplunkHecSinkSettings`.
- **Parameters.** `-Url` and `-Token` are the primary names. The third-party names (`-SplunkHost`,
  `-EventCollectorToken`, `-BatchIntervalSeconds`, `-HostName`) bind as aliases. A script moves over by changing its
  `Import-Module` line.
- **Validation.**
  - Options that belong to the other endpoint are errors: `-Fields` and `-DontRender*` with Raw, `-OutputTemplate`
    with Event.
  - A non-http(s) URL is an error.
  - An empty `-Fields` table is not passed on to the package.
- **Loading.** The psm1 loops with a `foreach` statement. A `throw` inside `ForEach-Object` in a module script did not
  stop the import (found here; the OTLP psm1 had the same defect and is fixed with it). Importing after a module that
  loaded an older Serilog.Sinks.Splunk therefore fails with a clear message.

## Alternatives considered

- **A PowerShell function over `WriteTo.EventCollector`, like the third-party module.**
  - Whole-second batching and an unbounded queue.
  - No raw endpoint with metadata.
  - Not unit-testable without a PowerShell host.
- **The third-party parameter names as primary names.** `-SplunkHost` takes a URL, not a host, and
  `-EventCollectorToken` is long. Aliases keep scripts working without carrying the confusing names into the docs.
- **A different command name (`Add-SinkSplunkHec`).** It avoids the clash in one session, but ADR 0009 chose names that
  let scripts move over, and the two modules cannot share a process anyway.
- **Only the event endpoint.** The brief asks for both, and raw is the route when a sourcetype already parses a line
  format.
- **`-Token` as SecureString.** No other PoShLog sink takes a SecureString. A HEC token ends up in a header, in clear
  text, either way, and the docs advise reading it from an environment variable or a secret store.

## Consequences

- The `lib/` folder ships only `Serilog.Sinks.Splunk.dll` and the cmdlet assembly.
- The module cannot load in a session after the third-party PoShLog.Sinks.Splunk. The docs page says to import only
  one, and the psm1 says why when it refuses.
- The compatibility suite runs the module alone, and next to Seq in both import orders: InRepo with the refreshed Seq,
  Published with Seq 1.0.0.
- The Gallery name `PoShLog.Sinks.Splunk.Hec` was free on 2026-11-03. Tomáš confirms it before the first publish
  (ADR 0009).
- A Splunk Cloud or Enterprise instance was not used for testing. A loopback HEC stand-in (`tests/PoShLog.Sinks.Splunk.Hec.Tests`)
  checks the paths, the headers, the token answer (403) and the payloads.
