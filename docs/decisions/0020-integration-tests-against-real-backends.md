# 0020 — Integration tests against real backends

- **Status:** proposed
- **Date:** 2026-11-03

## Context

Unit tests and construction smoke checks cannot establish that a sink delivers readable events to a server.
Tests also need to distinguish the modules users install after a release from freshly built PR artifacts.
Windows PowerShell 5.1 users must keep receiving the stable Core 2.x and extension 1.0.x lines.

## Decision

Add an opt-in Pester 5 suite, one file per module. Emit three uniquely identified events, flush with
Close-Logger, poll up to sixty seconds, and assert levels, rendered messages and a structured property for
every event. Assert environment/process/exception enrichers through JSON File output.

Use Gallery and InRepo modes in a shared runner. Gallery saves PSGallery packages (including prereleases while
Core 3 is a preview) to an isolated temp module path and prints resolved versions. InRepo publishes Core as CI
does and reuses Stage-Module/Build-Extension for extensions. Each module is tested in a clean child process.
Successful Release runs wait for Gallery indexing; daily and manual runs default to Gallery, PRs to InRepo.

Run Seq, OpenTelemetry Collector, Splunk, syslog-ng and Elasticsearch in exact-tag Linux containers. Read actual
server storage/search results, including Collector JSON-lines output and separate syslog transport files.
Create syslog's test certificate/key at runtime and pin its public certificate. Splunk's self-signed HEC TLS
is accepted by a test-only HTTP handler. Elasticsearch runs with security disabled. HTTP uses a real local
HttpListener, providing direct body inspection without maintaining another image.

Windows runners test EventLog by registering a unique source and querying Get-WinEvent. A separate Windows
PowerShell 5.1 job saves stable Gallery modules with PowerShellGet and asserts their major/minor versions.
It tests File/EventLog and receives Seq raw ingestion (Seq 1.0.x posts the JSON `{"Events":[...]}` envelope, not CLEF) with HttpListener because GitHub's Windows runner
cannot host Seq's Linux container. Actual Seq indexing/querying is covered by the Linux job.

## Alternatives considered

- Only mock receivers: useful for protocol tests, but cannot catch backend acceptance or indexing failures.
- Only Gallery tests: misses problems before publishing. Only InRepo tests: misses packaging and dependency resolution.
- Hosted cloud backends: require real credentials, cost and external state; unsuitable for fork PRs.
- Install modules into the developer's profile: contaminates assembly resolution and makes runs less reproducible.

## Consequences

- Docker startup, especially Splunk, increases runtime and resource use; jobs have timeouts and always tear down.
- Unique event IDs isolate runs. Backend diagnostics and Pester XML are uploaded on GitHub failures.
- Fixed dummy credentials are scoped to disposable, loopback-bound containers. No real credentials or TLS keys ship.
- Elastic Cloud/security, Splunk Cloud, real TLS trust chains and macOS integration remain uncovered.
- The 5.1 listener verifies Seq ingestion payloads, not Seq persistence. Windows EventLog verification needs elevation.
- New tests must not silently substitute in-repo modules in Gallery mode or activate during ordinary CI discovery.
