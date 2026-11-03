# 0012 — The OpenTelemetry sink: a compiled cmdlet, OTLP/HTTP by default, parameters before environment

- **Status:** proposed
- **Date:** 2026-11-03

## Context

PoShLog 3.0.0 gets an OTLP sink, `PoShLog.Sinks.OpenTelemetry`, over `Serilog.Sinks.OpenTelemetry` 4.2.0. OTLP
reaches Seq, Grafana, .NET Aspire, the Datadog Agent and every OpenTelemetry Collector with one module, so it is the
route ADR 0009 recommends for Datadog and the comparison point for the other first-party sinks. Facts that shaped
the design, verified against the package on 2026-11-03:

- The package defaults to **gRPC on port 4317**. The OpenTelemetry specification makes `http/protobuf` the SDK
  default, and OTLP/HTTP passes proxies that block HTTP/2.
- With OTLP/HTTP it **appends `/v1/logs`** to the endpoint path (`http://h:5341/ingest/otlp` posts to
  `/ingest/otlp/v1/logs`).
- Unless told to ignore it, the package reads `OTEL_EXPORTER_OTLP_ENDPOINT`, `_PROTOCOL`, `_HEADERS`,
  `OTEL_RESOURCE_ATTRIBUTES` and `OTEL_SERVICE_NAME`, and these **override the code**: with the endpoint variable set,
  a script's `-Endpoint` was silently ignored and nothing reached it. The OpenTelemetry SDKs do it the other way
  round: code first, environment as the default.
- The package depends on Google.Protobuf, Grpc.Core.Api, Grpc.Net.Client, Grpc.Net.Common and
  Microsoft.Extensions.Logging.Abstractions. None is shipped by Core (ADR 0011) or by another first-party extension,
  nor by the published PoShLog.Sinks.Seq 1.0.0. A future extension (Elastic, a gRPC-based sink) may ship one of them.
  Two `Add-Type -Path` calls for the same assembly name fail with "Assembly with same name is already loaded"
  (ADR 0007).
- `release.yml` accepts only `major.minor.patch` versions.

## Decision

- **A compiled `Add-SinkOpenTelemetry` cmdlet** in `PoShLog.Sinks.OpenTelemetry.dll`, built from the module's
  `Dependencies.csproj` like Http's `Get-ApiKeyHttpClient`. The mapping from parameters to the package's options lives
  in `OpenTelemetrySinkSettings`, which the xUnit tests cover without a runspace.
- **Defaults:** `-Protocol HttpProtobuf`; `-Endpoint` is the base URL, `http://localhost:4318` for HTTP and
  `http://localhost:4317` for gRPC. `/v1/logs` is the package's to append and is documented, not re-implemented.
- **Parameters win, the environment fills in.** The sink passes the package an environment reader that hides a
  variable when the matching parameter was given: the endpoint and protocol variables when `-Endpoint` or
  `-Protocol` is bound, `OTEL_SERVICE_NAME` when the service name is set in code, and the keys of the
  `key=value` lists in `OTEL_EXPORTER_OTLP_HEADERS` and `OTEL_RESOURCE_ATTRIBUTES` that are given in code (headers
  compared without case). `-IgnoreEnvironment` hides all of them. Without parameters the variables are used, which is
  how .NET Aspire configures the processes it starts.
- **Version-aware loading.** The psm1 is the root module. For each assembly in `lib/` it reuses an assembly of the
  same name that is already loaded at the same or a higher version, throws a message naming both versions when a
  lower one is loaded, and `Add-Type`s it otherwise. Then it imports the cmdlet assembly. There are no
  `NestedModules`, so the dependencies are loaded before PowerShell reads the cmdlet's metadata.
- **Version 0.1.0**, `RequiredModules` PoShLog 3.0.0 by GUID (ADR 0004), PowerShell 7.4. A 0.x version marks the
  preview without a prerelease suffix that the release workflow would reject. It goes to 1.0.0 once PoShLog 3.0.0 is
  released and the sink has been used against a real backend.
- **Compatibility:** InRepo runs the sink alone and next to the in-repo Seq extension, imported before and after it;
  Published runs it next to the published Seq 1.0.0 in both orders (the OTLP build is added to that job).
  `Invoke-Compatibility.ps1 -LegacySeqPath` runs the 1.0.0 pairing locally from an extracted copy, since downloading
  published modules is restricted to GitHub Actions.

## Alternatives considered

- **A script function calling the package's simple overload** (as `Add-SinkSeq` does). The simple overload has no
  batching options and no environment reader, and a function cannot express the "was this parameter bound" rule
  cleanly for every option; the logic would be untested PowerShell.
- **Keep the package's gRPC default.** It would match the package's own docs, but not the OpenTelemetry default
  that Aspire, Seq and Loki document for HTTP, and gRPC needs HTTP/2 end to end.
- **Pass the environment through unchanged (the package's behaviour).** A machine-wide `OTEL_EXPORTER_OTLP_ENDPOINT`
  would redirect every script that names its own endpoint, with no error. Rejected as surprising.
- **Always ignore the environment.** Scripts run by Aspire or under a configured collector would need their
  endpoint repeated in code; the standard variables are the point of OTLP.
- **Load the dependencies into their own AssemblyLoadContext.** The sink implements Serilog's `ILogEventSink` from
  the default context, so it cannot live in another one (the reason ADR 0003 and 0007 give).
- **`Add-Type` every `lib` assembly unconditionally** (the other extensions' psm1). It breaks the day a second module
  in the session ships Google.Protobuf.
- **Version 1.0.0-preview.** Correct semantic versioning, but `release.yml` would need a prerelease field and
  `Prerelease` in the manifest for a single module; 0.1.0 needs neither.

## Consequences

- A user can move from Seq to Grafana or Datadog by changing the endpoint and a header; the docs page shows each.
- The environment rules are PoShLog's, not the package's. The docs list them, and a package upgrade must keep the
  tests in `OpenTelemetrySinkSettingsTests` and the Pester environment tests green.
- If a module loaded earlier ships a newer Protobuf or gRPC, the sink uses it; if it ships an older one, importing
  the sink fails with a message to import it first. The older-version path is covered by code review only.
- The compat job for Published mode builds the OTLP sink. The xUnit project hosts a Kestrel receiver for OTLP/HTTP and
  h2c gRPC, so the tests need no container.
- `Stage-Module.ps1` stages a module without a `functions/` directory.
