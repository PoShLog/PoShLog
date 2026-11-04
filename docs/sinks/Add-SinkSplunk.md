### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.Splunk.Hec](../../extensions/PoShLog.Sinks.Splunk.Hec/README.md)
(PowerShell 7.6+, PoShLog 3.0.0+).

```ps1
Install-Module PoShLog.Sinks.Splunk.Hec
```

# Add-SinkSplunk `EXTENSION`

Sends log events to a Splunk HTTP Event Collector (HEC), as Splunk JSON events or as raw text lines.

```ps1
Add-SinkSplunk
    [-LoggerConfig] <LoggerConfiguration>
    [-Url] <string>
    [-Token] <string>
    [-Endpoint <HecEndpoint>]
    [-UriPath <string>]
    [-Index <string>]
    [-Source <string>]
    [-SourceType <string>]
    [-HostName <string>]
    [-Fields <IDictionary>]
    [-OutputTemplate <string>]
    [-FormatProvider <IFormatProvider>]
    [-DontRenderTemplate]
    [-DontRenderMessage]
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-LevelSwitch <LoggingLevelSwitch>]
    [-BatchInterval <TimeSpan>]
    [-BatchSizeLimit <int>]
    [-QueueLimit <int>]
    [-HttpMessageHandler <HttpMessageHandler>]
    [<CommonParameters>]
```

## Description

HEC is Splunk's HTTP intake: no forwarder and no OpenTelemetry Collector are needed, only the collector URL (port 8088
by default) and a token. Create the token in Splunk Web under **Settings → Data inputs → HTTP Event Collector**.

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.Splunk.Hec

New-Logger |
    Add-SinkSplunk -Url 'https://splunk.example.com:8088' -Token $env:SPLUNK_HEC_TOKEN -Index 'main' -Source 'nightly-backup' |
    Start-Logger

Write-InfoLog 'Backed up {Count} databases' -PropertyValues 12
Close-Logger
```

Events are batched and sent in the background. `Close-Logger` flushes what is still queued, so call it before the
script ends. Keep the token out of the script: read it from an environment variable or a secret store.

### Event endpoint (default)

Each log event becomes one HEC event on `services/collector/event`:

```json
{"time":"1793700087.799","event":{"Level":"Information","MessageTemplate":"Backed up {Count} databases",
 "RenderedMessage":"Backed up 12 databases","Properties":{"Count":12}},"source":"nightly-backup","index":"main"}
```

With a JSON sourcetype such as `_json`, Splunk extracts `event.Properties.*` as search-time fields
(`index=main event.Properties.Count>10`). `-Fields` adds
indexed fields to every event: `-Fields @{ team = 'ops'; tags = 'backup', 'nightly' }`.

String values in `RenderedMessage` are quoted (`"Hello \"Tomas\""`), as in Serilog's default rendering.

### Raw endpoint

`-Endpoint Raw` posts text lines to `services/collector/raw`, rendered with `-OutputTemplate`. Index, source, sourcetype
and host travel in the query string. Use it when a sourcetype already parses a line format.

```ps1
New-Logger |
    Add-SinkSplunk -Url 'https://splunk.example.com:8088' -Token $token -Endpoint Raw -SourceType 'poshlog:line' `
        -OutputTemplate '{Timestamp:o} {Level:u3} {Message:lj}{NewLine}' |
    Start-Logger
```

The default template is `{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}`. An
exception spans several lines, and Splunk splits raw input into events by the sourcetype's line breaking. Prefer the
event endpoint when you log exceptions.

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `-Url` | required | HEC base URL, such as `https://splunk.example.com:8088`; For Splunk Cloud Platform, take the HEC URL of your stack from Splunk's HEC documentation. A URL whose path already contains `services/collector` is used as it is. Aliases `-SplunkHost`, `-Uri`. |
| `-Token` | required | HEC token, sent as `Authorization: Splunk <token>`. Alias `-EventCollectorToken`. |
| `-Endpoint` | `Event` | `Event` (Splunk JSON on `services/collector/event`) or `Raw` (text lines on `services/collector/raw`). |
| `-UriPath` | by endpoint | A different collector path, such as one behind a proxy. |
| `-Index` | token default | Target index. The token must be allowed to write to it. |
| `-Source`, `-SourceType` | token default | The `source` and `sourcetype` of the events. |
| `-HostName` | sender address | The `host` field. Alias `-Host`. |
| `-Fields` | none | Indexed fields; a list value becomes a multi-value field. Event endpoint only. |
| `-OutputTemplate` | see above | Line format. Raw endpoint only. |
| `-FormatProvider` | current culture | Culture used for rendering the message. |
| `-DontRenderTemplate`, `-DontRenderMessage` | off | Leave `MessageTemplate` or `RenderedMessage` out of the event JSON. Event endpoint only. |
| `-RestrictedToMinimumLevel` | `Verbose` | Lowest level this sink receives. |
| `-LevelSwitch` | none | A `LoggingLevelSwitch` that changes the sink's level at run time. |
| `-BatchInterval` | 2 seconds | How long events are buffered before a request. A number means seconds (`-BatchInterval 0.5`). Alias `-BatchIntervalSeconds`. |
| `-BatchSizeLimit` | 100 | Maximum events per request. |
| `-QueueLimit` | 100000 | Maximum events waiting to be sent; later events are dropped. |
| `-HttpMessageHandler` | default | Handler for the HTTP client, such as a proxy or a client certificate. |

## Delivery and errors

- A request that fails with a network error or any other error status is retried with back-off.
- Splunk answers 400, 403 or 405 for a malformed request, a wrong or disabled token, or an index the token may not
  write to. The batch is then dropped: retrying cannot succeed. Turn on `Enable-SelfLog` to see the reason.
- A self-signed certificate on port 8088 fails TLS validation. Install the certificate as trusted, or pass an
  `-HttpMessageHandler` that validates it on purpose. Do not turn validation off in production.

## Migrating from PoShLog.Sinks.Splunk

PoShLog.Sinks.Splunk (Mike Powell) is another author's module on Serilog.Sinks.Splunk 3.7.0. This module keeps the
command name and binds its parameter names as aliases, so most scripts only change the `Import-Module` line.

| PoShLog.Sinks.Splunk 1.0.4 | PoShLog.Sinks.Splunk.Hec | Note |
|---|---|---|
| `-SplunkHost` | `-Url` | Alias kept. |
| `-EventCollectorToken` | `-Token` | Alias kept. |
| `-UriPath` (default `services/collector`) | `-UriPath` (default `services/collector/event`) | Both accept the JSON envelope; `-Endpoint Raw` selects the raw endpoint. |
| `-Source`, `-SourceType`, `-Index` | same | |
| `-HostName` | `-HostName` | Also `-Host`. |
| `-RestrictedToMinimumLevel`, `-LevelSwitch`, `-FormatProvider`, `-DontRenderTemplate` | same | |
| `-BatchIntervalSeconds` (int) | `-BatchInterval` (TimeSpan or seconds) | Alias kept; fractions of a second work. |
| `-BatchSizeLimit` | same | Default 100 in both. |
| `-QueueLimit` (default unbounded) | same (default 100000) | Bounded by default. |
| `-HttpMessageHandler` | same | |
| — | `-Endpoint`, `-Fields`, `-OutputTemplate`, `-DontRenderMessage` | New. |

Import only one of the two modules into a session. They ship different versions of Serilog.Sinks.Splunk, and one
process can load only one of them. PoShLog.Sinks.Splunk.Hec refuses to import after the other module and says why.

## OTLP or HEC?

Splunk takes OpenTelemetry data through the Splunk Distribution of the OpenTelemetry Collector. Use
[Add-SinkOpenTelemetry](Add-SinkOpenTelemetry.md) when a collector already runs or the same logs also go to another
backend, and `Add-SinkSplunk` when scripts write straight to Splunk.
