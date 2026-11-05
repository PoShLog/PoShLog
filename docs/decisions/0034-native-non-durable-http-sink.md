# 0034 — Own the non-durable HTTP sink

- **Status:** accepted
- **Date:** 2026-11-05
- **Supersedes:** the published Http Desktop compatibility claim in [0031](0031-windows-powershell-desktop-support.md), under "Assembly resolution on Desktop" (line 84). The same line's EventLog claim is narrowed: published EventLog 1.0.1 only, for configuration checks.
- **Related:** [0011](0011-core-does-not-load-assemblies-extensions-ship.md), [0019](0019-extensions-ship-as-prereleases-during-the-core-3-preview.md), [0033](0033-net10-powershell-7-6.md).

## Context

Tomáš chose the native HTTP sink before PoShLog v3 proceeds. Published Http 1.0.1 loads its bundled Serilog 2 on Desktop alongside Core's Serilog 4.4. `Add-SinkHttp` then fails parameter binding because the two `LoggerConfiguration` types have different assembly identities. It is unsupported with v3 Core on Desktop; ADR 0031's general statement that the resolver enables published Http is superseded only on this point.

The current in-repo extension uses Serilog.Sinks.Http 9.2.1 for public transport/formatter contracts and normal rendered JSON formatting. Its configuration dependency adds assemblies outside Core's shared ownership. ADR 0031 requires evaluating own code before isolation. Non-durable HTTP POST needs only inbox networking and Serilog's existing batching, so owning this bounded feature avoids that dependency graph.

## Decision

Replace Serilog.Sinks.Http with PoShLog's own non-durable HTTP sink, targeting net472 for Windows PowerShell 5.1 and net10.0 for PowerShell 7.6+, using inbox APIs and Core-owned Serilog 4.4 batching. Ship only PoShLog.Sinks.Http.dll per target; retain the upcoming 2.0.0 line with the next shared label, preview4, without publishing it.

`Add-SinkHttp` and `Get-ApiKeyHttpClient` retain their names and parameters; `TextFormatter` aliases `Formatter`. Native `PoShLog.Sinks.Http.IBatchFormatter` and `IHttpClient` replace upstream identities. `Configuration` is `IDictionary`, including `http:apiKey` for `X-Api-Key`. A supplied client transfers ownership to one sink, is configured once when a dictionary is supplied, and is disposed after batching shutdown. Custom clients must observe cancellation and finite request deadlines.

Keep the 9.2.1 normal rendered event schema and array payload, verified by direct output comparison against that version in tests. Adapted formatter source retains its Apache-2.0 licence and notices. `LegacyBatchFormatter` supplies the published 1.0.1 `{"events":[...]}` envelope and a configurable 256-KiB UTF-8 event limit (explicit null disables the limit).

The default queue admits 100,000 waiting events; explicit null is unbounded. Batch size defaults to 1,000, period to two seconds, with eager first delivery. Serilog owns admission, exponential retry and its default ten-minute retry horizon. Every non-2xx response fails; automatic redirects are disabled. Requests have a 30-second deadline. The modern handler recycles pooled connections after two minutes; Desktop retains inbox handler proxy, OS TLS and certificate validation defaults.

`Close-Logger` disposes the batching wrapper, attempts remaining delivery and then disposes transport. There is no aggregate shutdown deadline: a failed shutdown attempt stops draining, and multiple successful batches can take multiple request deadlines. A hung endpoint blocks `Close-Logger` for about 60 seconds, measured on both hosts: the in-flight request and one shutdown attempt. The count limit bounds event references (approximately queue plus active batch), not bytes or arbitrary event graphs. Restart loses queued events and lost acknowledgements can cause duplicates.

Desktop Published compatibility pins EventLog 1.0.1 (configuration only, without creating a source or writing an entry) and excludes unsupported Http 1.0.1. EventLog 1.0.0 reports "not supported on this platform"; Http 1.0.1 reports an `Add-SinkHttp` parameter binding error. Modern pins are unchanged. Native HTTP delivery and both import orders are tested separately on each real host.

Disabling redirects is deliberate and changes behaviour for existing endpoints. Measured with a default HttpClient on both hosts, a 302 turns the POST into a body-less GET and the final 200 reports success, so the batch is lost silently, and `X-Api-Key` is forwarded to the other origin. A 307 keeps the POST but forwards the key too. An endpoint that answers with a redirect now fails visibly through SelfLog and Serilog's retries. A custom `IHttpClient` can follow redirects if an endpoint needs it.

## Alternatives considered

- **Keep upstream on Desktop:** net462 assets exist, but bundling configuration dependencies expands Core's ownership boundary and leaves the collision risk. Own code covers the required subset.
- **Shade or isolate upstream:** unnecessary complexity for non-durable POST, and Desktop has no AssemblyLoadContext. Own code comes first under ADR 0031.
- **Durable parity:** file buffers, replay, bookmarks and retention enlarge the feature and lifecycle substantially; out of scope.
- **Use Serilog JsonFormatter directly:** its schema differs from the current extension's normal rendered format.
- **Reproduce the full convenience catalogue:** gzip, Retry-After and other upstream formatters/clients are deferred; native contracts retain custom extension points.

## Consequences

- Windows PowerShell 5.1 can deliver HTTP without another Serilog identity or Microsoft.Extensions assemblies in the extension package.
- Existing custom upstream clients/formatters must migrate namespaces, recompile against native contracts and replace IConfiguration with IDictionary. Direct use of upstream durable APIs and convenience types is no longer supplied transitively.
- Endpoints that redirect must be addressed directly, or served through a custom client. JSON configuration uses the native method's argument names; upstream-only names fail with the binder's error, and `queueLimitBytes` accepts only null.
- Omitted QueueLimit changes from unlimited to 100,000. Explicit null preserves unbounded behaviour. Published 1.0.1 users choose the legacy batch formatter to retain their envelope.
- The sink owns transport/formatter maintenance, while retry and batching remain Serilog's responsibility. SelfLog reports failures; delivery is best effort, not durable or exactly once.
- This decision does not change other extension ports, authorize publishing, or establish coexistence with arbitrary third-party modules.
