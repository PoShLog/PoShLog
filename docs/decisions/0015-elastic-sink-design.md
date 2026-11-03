# 0015 — The Elastic sink: data streams over the bulk API, dropping when the buffer is full

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Builds on:** [0009](0009-first-party-sinks-third-party-check-non-blocking.md) (name and scope),
  [0012](0012-otlp-sink-design.md) (module layout), [0013](0013-splunk-hec-sink-design.md),
  [0014](0014-syslog-sink-design.md) (version-aware loading by file version)

## Context

ADR 0009 calls for a first-party sink that writes straight into Elasticsearch data streams, without an APM Server or an
OpenTelemetry Collector. Its module is `PoShLog.Sinks.Elastic`; Tomáš confirmed the Gallery name on 2026-11-03. The
existing third-party PoShLog.Sinks.Elasticsearch (mamidenn, 1.0.0-alpha5) wraps the retired Serilog.Sinks.Elasticsearch
8.4.1. It writes to classic indices (`-IndexFormat`), and it is Windows PowerShell only (ADR 0002), so it never loads
next to this module.

Elastic.Serilog.Sinks 9.0.0, Elastic's current package, constrains the design:

- It writes Elastic Common Schema (ECS) documents to a data stream (`type-dataset-namespace`) through the bulk API.
- Before the first bulk request, the client sends `HEAD /` and needs the response header `X-Elastic-Product:
  Elasticsearch`. Without that header, every batch fails.
- `BootstrapMethod` defaults to None. Silent and Failure install an index template and component templates first.
- The buffer (Elastic.Channels) waits when it is full (`BoundedChannelFullMode.Wait`), so logging blocks the caller.
- A buffer lifetime under one second is ignored, and the default of five seconds stays.
- The ECS formatter adds `host.*`, `process.*` and `user.*` fields to every document by default.
- Elastic.Channels, Elastic.Ingest.* and Elastic.Transport carry assembly version 0.0.0.0 in every release.
- No package here ships PeriodicBatching, and Serilog.dll is the only shared assembly.

## Decision

`Add-SinkElasticsearch` is a compiled cmdlet with the layout of ADR 0012: `Dependencies.csproj`, a version-aware psm1,
and no Serilog.dll in `lib/`. `ElasticSinkSettings` holds the validation and turns the parameters into the package's
sink and transport options.

- **Target.**
  - `-Node` takes one or more URLs (alias `-Uri`, the third-party name).
  - `-CloudId` targets an Elastic Cloud deployment and needs `-ApiKey` or `-Credential`.
  - `-ApiKey` and `-Credential` (basic authentication) are mutually exclusive. A node without credentials is allowed,
    for a cluster without security or a proxy that authenticates.
- **Data stream.**
  - `-DataStream` defaults to `logs-poshlog-default`. That name matches the cluster's built-in `logs-*-*` template, so
    the default needs no bootstrap.
  - The name is validated as three lowercase parts.
  - `-BootstrapMethod` defaults to None, as in the package. `-IlmPolicy` without a bootstrap is an error, because only
    the bootstrap applies it.
- **TLS.**
  - The system trust store validates the server.
  - `-CertificateFingerprint` pins the SHA-256 fingerprint of a self-signed CA, such as the one Elasticsearch 8
    generates.
  - There is no switch that skips validation.
- **Buffer.**
  - `-BatchInterval` defaults to 2 seconds, as in the other PoShLog sinks, and must be at least 1 second. A bare number
    means seconds.
  - `-BatchSizeLimit` defaults to 1000, the package's bulk size.
  - `-QueueLimit` defaults to 100000.
  - The full mode is `DropWrite`: a full queue drops new events instead of stalling the script.
- **ECS fields.** The package's ECS defaults stay. `-ExcludeHost`, `-ExcludeProcess` and `-ExcludeUser` leave those field
  groups out.
- **Diagnostics.** Each of these goes to Serilog's SelfLog, so `Enable-SelfLog` shows why nothing arrives:
  - an export exception, reported as its innermost message (refused connection, bad credentials, untrusted certificate);
  - a bulk response with an error status;
  - each document the server rejects;
  - events dropped after the last retry.
- **Loading.** The psm1 follows the Syslog sink (ADR 0014). When a loaded copy has the same assembly version, the psm1
  compares file versions, so an older Elastic.Channels 0.0.0.0 is told apart from the one shipped here. An older copy
  makes the import fail with a clear message.

## Alternatives considered

- **A PowerShell function over `WriteTo.Elasticsearch`.**
  - It would expose the package's blocking buffer and its silent one-second minimum.
  - It would hide the failure reasons.
  - It would not be unit-testable without a PowerShell host.
- **The third-party parameters (`-IndexFormat`, `-AutoRegisterTemplate`, `-SkipServerCertificateCheck`).**
  - Classic indices and their templates are what Elastic retired in favour of data streams.
  - Turning off certificate validation is what a pinned fingerprint replaces.
  - Only `-Uri` keeps its meaning, so it is the only alias.
- **The package's `Wait` full mode.** It guarantees delivery while the cluster keeps up. When the cluster is down, it
  stalls every `Write-*Log` call once 100000 events are queued. The other PoShLog sinks drop instead, and scripts should
  not hang on logging.
- **Bootstrap by default (Silent).** It needs the `manage_index_templates` privilege, which a writer-only API key
  should not have. The built-in `logs-*-*` template already gives a `logs-` data stream its mappings and lifecycle.
- **The package's data stream `logs-dotnet-default`.** PowerShell logs would mix with .NET applications' logs in one
  dataset.
- **Leaving out the host, process and user fields by default.** They identify the machine and the account. Kibana's
  views expect them, and the package includes them. The switches cover the cases that need less.

## Consequences

- `lib/` ships seven Elastic assemblies and the cmdlet assembly. Elastic.Transport needs no extra runtime dependencies
  on .NET 8.
- A full queue now loses events instead of blocking. SelfLog does not report a dropped write; a queue that size is
  only reached when the cluster stays unreachable.
- `service.name` in the documents is the process name (`pwsh`), as the package sets it. Scripts can tell themselves
  apart with an enricher or a `-DataStream` per script.
- The shared compat listener now sends the product header, answers HEAD without a body, and answers `_bulk` with one
  item per document. The other HTTP sinks ignore all three.
- The compatibility suite runs the module alone, and next to Seq in both import orders, InRepo and Published.
- A real Elasticsearch or Elastic Cloud deployment was not used for testing. A loopback stand-in
  (`tests/PoShLog.Sinks.Elastic.Tests`) checks:
  - the product check, the paths, the headers and the document shape;
  - the 401 answer and rejected documents;
  - template installation.
