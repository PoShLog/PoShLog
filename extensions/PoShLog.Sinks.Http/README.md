# PoShLog.Sinks.Http

Native, non-durable HTTP POST sink for Windows PowerShell 5.1 (.NET Framework 4.7.2+) and PowerShell 7.6+ (.NET 10).
The upcoming 2.0.0-preview4 requires PoShLog 2.99.0 by GUID during the Core 3 preview; PoShLog 2.x users stay on 1.0.x.
Core supplies Serilog 4.4. The extension ships only its own binary for each runtime, with no Serilog.Sinks.Http or Microsoft.Extensions dependencies.

Build and use from the repository root:

```powershell
./build/Build-Core.ps1
./build/Build-Extension.ps1 -Module PoShLog.Sinks.Http
Import-Module ./src/PoShLog.psd1
Import-Module ./extensions/PoShLog.Sinks.Http/PoShLog.Sinks.Http.psd1
New-Logger | Add-SinkHttp -RequestUri 'http://localhost:8080/events' | Start-Logger
Write-InfoLog 'Hello {Number}' -PropertyValues 42
Close-Logger
```

## Parameters and delivery

`Add-SinkHttp` keeps `LoggerConfig`, `RequestUri`, `BatchPostingLimit`, `QueueLimit`, `Period`, `Formatter`,
`BatchFormatter`, `RestrictedToMinimumLevel`, `HttpClient` and `Configuration`. `TextFormatter` is an alias of `Formatter`.
The URI must be absolute HTTP/HTTPS; batch size, finite queue size and period must be positive.

Defaults: 1,000 events per batch, 100,000 waiting events, two-second period and eager first delivery. Explicit
`-QueueLimit $null` remains unbounded. A full queue drops incoming events. Count limits do not bound payload bytes or event graph memory.
The default payload is a JSON array using `NormalRenderedTextFormatter`: UTC timestamp, level, message template,
rendered message and optional exception, properties, renderings, trace and span IDs. Tests compare it directly with Serilog.Sinks.Http 9.2.1 output.

Every non-2xx response, including redirects, fails. Serilog schedules retries with its default ten-minute horizon;
there is no Retry-After handling. Both the sink's cancellation token and the default client's timeout limit a request
to 30 seconds. The modern connection pool lifetime is two minutes. Desktop uses the inbox HttpClientHandler with
OS TLS, proxy and certificate validation defaults. Automatic redirects are disabled.

`Close-Logger` attempts to flush pending batches and disposes transport afterwards. There is no total flush deadline;
a failed shutdown delivery stops the drain. Restart loses memory buffers, persistent failures can discard events,
and a lost acknowledgement can duplicate a delivery. Enable Core's SelfLog for delivery diagnostics.

## Authentication and custom contracts

`Get-ApiKeyHttpClient -ApiKey` returns the native client that sends `X-Api-Key`. Alternatively pass
`-Configuration @{ 'http:apiKey' = $apiKey }`; this replaces a constructor key when both are supplied.
Use HTTPS for remote authenticated endpoints.

Implement `PoShLog.Sinks.Http.IBatchFormatter.Format(IEnumerable<string>, TextWriter)` for a custom batch payload.
Individual formatters still use Core's `Serilog.Formatting.ITextFormatter`. Implement `PoShLog.Sinks.Http.IHttpClient`
with `Configure(IDictionary)`, `PostAsync(string, Stream, CancellationToken)` and `Dispose()` for custom transport.
Configuration runs once if supplied. A client belongs to one sink: do not share it between sinks. Observe the cancellation
token and finite timeouts, return a response for the sink to dispose, and do not retain the request stream after PostAsync completes.

## Migration

- Custom clients and batch formatters using `Serilog.Sinks.Http` interfaces must migrate and recompile against the native contracts. `Configuration` now accepts `System.Collections.IDictionary`, replacing Microsoft IConfiguration.
- Omitted `QueueLimit` is now 100,000; pass explicit `$null` to retain unlimited admission.
- Published 1.0.1 used an events envelope. Select it explicitly with
  `-BatchFormatter ([PoShLog.Sinks.Http.BatchFormatters.LegacyBatchFormatter]::new())`.
  Its default per-event UTF-8 limit is 256 KiB; pass a different nullable byte limit to the constructor, or `$null` for unlimited.
  This restores the envelope and event limit; the event schema remains the current normal rendered schema.
- Upstream durable APIs, gzip and other convenience clients/formatters are no longer available through a transitive assembly.
- Published Http 1.0.1 is unsupported with v3 Core on Desktop: `Add-SinkHttp` fails parameter binding because it loads a second Serilog identity.
  Published EventLog 1.0.0 reports "not supported on this platform"; 1.0.1 passes configuration checks only (no Event Log write claim).
  Modern published compatibility pins are unchanged. See [compatibility](../../docs/compatibility.md) and [ADR 0034](../../docs/decisions/0034-native-non-durable-http-sink.md).

See the [extension build guide](../README.md) and [migration guide](../../docs/guides/migration-v3.md).
