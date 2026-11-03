### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.OpenTelemetry](../../extensions/PoShLog.Sinks.OpenTelemetry/README.md)
(PowerShell 7.4+, PoShLog 3.0.0+).

```ps1
Install-Module PoShLog.Sinks.OpenTelemetry
```

# Add-SinkOpenTelemetry `EXTENSION`

Sends log events as OpenTelemetry (OTLP) log records over HTTP/protobuf or gRPC.

```ps1
Add-SinkOpenTelemetry
    [-LoggerConfig] <LoggerConfiguration>
    [[-Endpoint] <string>]
    [-Protocol <OtlpProtocol>]
    [-Headers <IDictionary>]
    [-ResourceAttributes <IDictionary>]
    [-ServiceName <string>]
    [-IncludedData <IncludedData>]
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-LevelSwitch <LoggingLevelSwitch>]
    [-BatchSizeLimit <int>]
    [-Period <TimeSpan>]
    [-QueueLimit <int>]
    [-HttpMessageHandler <HttpMessageHandler>]
    [-IgnoreEnvironment]
    [<CommonParameters>]
```

## Description

OTLP is the vendor-neutral protocol of OpenTelemetry. One sink reaches an OpenTelemetry Collector and every backend
with an OTLP intake, so a script can switch from Seq to Grafana or Datadog by changing the endpoint and a header.

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.OpenTelemetry

New-Logger |
    Add-SinkOpenTelemetry -Endpoint 'http://localhost:4318' -ServiceName 'nightly-backup' |
    Start-Logger

Write-InfoLog 'Backed up {Count} databases' -PropertyValues 12
Close-Logger
```

Events are batched and sent in the background. `Close-Logger` flushes what is still queued, so call it before the
script ends.

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `-Endpoint` | `http://localhost:4318` (HTTP), `http://localhost:4317` (gRPC) | Base URL of the receiver. With `HttpProtobuf`, `/v1/logs` is appended to its path: `http://seq:5341/ingest/otlp` posts to `/ingest/otlp/v1/logs`. |
| `-Protocol` | `HttpProtobuf` | `HttpProtobuf` (OTLP/HTTP, port 4318) or `Grpc` (OTLP/gRPC, port 4317). HTTP is the OpenTelemetry default and passes most proxies. |
| `-Headers` | none | Hashtable of HTTP headers (gRPC metadata), usually the API key: `@{ 'X-Seq-ApiKey' = $key }`. |
| `-ResourceAttributes` | none | Hashtable describing the source: `@{ 'deployment.environment' = 'prod'; 'host.name' = $env:COMPUTERNAME }`. |
| `-ServiceName` | none | Shortcut for the `service.name` resource attribute; most backends group logs by it. |
| `-IncludedData` | message template text, trace and span ids, required resource attributes | Flags of `Serilog.Sinks.OpenTelemetry.IncludedData`, for example `'TemplateBody, SourceContextAttribute'`. |
| `-RestrictedToMinimumLevel` | `Verbose` | Drops events below this level for this sink only. |
| `-LevelSwitch` | none | A level switch from `New-LevelSwitch` to change the level at run time. |
| `-BatchSizeLimit` | 1000 | Maximum events per export request. |
| `-Period` | 2 seconds | How long events are buffered before an export. |
| `-QueueLimit` | 100000 | Maximum events waiting for export; further events are dropped. |
| `-HttpMessageHandler` | none | Handler for the exporter's HTTP client: a proxy, a client certificate, or a test double. |
| `-IgnoreEnvironment` | off | Ignore all `OTEL_*` variables (see below). |

Event properties become log record attributes. `Write-ErrorLog -Exception` adds `exception.type`,
`exception.message` and `exception.stacktrace`.

## Environment variables

The standard OpenTelemetry variables fill in what the parameters leave out:

| Variable | Used when |
|---|---|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `-Endpoint` is not given |
| `OTEL_EXPORTER_OTLP_PROTOCOL` (`grpc` or `http/protobuf`) | `-Protocol` is not given |
| `OTEL_EXPORTER_OTLP_HEADERS` (`key1=value1,key2=value2`) | always; a header also given in `-Headers` keeps the parameter's value |
| `OTEL_RESOURCE_ATTRIBUTES` (`key1=value1,...`) | always; an attribute also given in code keeps the code's value |
| `OTEL_SERVICE_NAME` | neither `-ServiceName` nor a `service.name` resource attribute is given |

A parameter always wins over the environment. `-IgnoreEnvironment` makes the sink use only its parameters, for
example in a script that must not follow a collector configured for the machine. This is how .NET Aspire configures
the processes it starts (see below): without `-Endpoint`, a script started by Aspire logs to its dashboard.

## Setups

The examples use placeholders (`<api-key>`, `<host>`). Check the vendor's documentation for the current endpoint of
your region and plan; the PoShLog tests run only against local receivers.

### Seq

Seq 2024.1 and later ingest OTLP logs on its HTTP port under `/ingest/otlp`.

```ps1
New-Logger |
    Add-SinkOpenTelemetry -Endpoint 'http://localhost:5341/ingest/otlp' -Headers @{ 'X-Seq-ApiKey' = '<api-key>' } -ServiceName 'backup' |
    Start-Logger
```

`Add-SinkSeq` (PoShLog.Sinks.Seq) remains the choice for older Seq versions and for Seq's own CLEF features. Both
modules can be imported in the same session.

### .NET Aspire dashboard

Standalone dashboard in a container; port 4318 is mapped to the dashboard's OTLP/HTTP port:

```bash
docker run --rm -d -p 18888:18888 -p 4317:18889 -p 4318:18890 --name aspire-dashboard mcr.microsoft.com/dotnet/aspire-dashboard:9.0
```

```ps1
New-Logger | Add-SinkOpenTelemetry -Endpoint 'http://localhost:4318' -ServiceName 'backup' | Start-Logger
```

Open `http://localhost:18888` (the login token is printed in the container log) and look under **Structured logs**.
When the dashboard requires an OTLP API key (`DASHBOARD__OTLP__AUTHMODE=ApiKey`), add
`-Headers @{ 'x-otlp-api-key' = '<api-key>' }`.

Inside an Aspire app host, a script started as an executable resource receives `OTEL_EXPORTER_OTLP_ENDPOINT`,
`OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_EXPORTER_OTLP_HEADERS` and `OTEL_SERVICE_NAME`, so `Add-SinkOpenTelemetry` with
no parameters is enough.

### Grafana Loki and Grafana Cloud

Loki 3 accepts OTLP directly under `/otlp`:

```ps1
New-Logger | Add-SinkOpenTelemetry -Endpoint 'http://loki:3100/otlp' -ServiceName 'backup' | Start-Logger
```

Through Grafana Alloy (or any OpenTelemetry Collector) with an `otelcol.receiver.otlp` component, send to the
collector instead: `-Endpoint 'http://alloy:4318'`. For Grafana Cloud, use the stack's OTLP gateway and Basic
authentication with the instance id and an access token:

```ps1
$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('<instance-id>:<token>'))
New-Logger |
    Add-SinkOpenTelemetry -Endpoint 'https://otlp-gateway-<zone>.grafana.net/otlp' -Headers @{ Authorization = "Basic $basic" } -ServiceName 'backup' |
    Start-Logger
```

### Datadog

The Datadog Agent receives OTLP once OTLP ingestion and logs are enabled
(`DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT=0.0.0.0:4318`, `DD_OTLP_CONFIG_LOGS_ENABLED=true`). The script talks
to the local Agent, which holds the API key:

```ps1
New-Logger |
    Add-SinkOpenTelemetry -Endpoint 'http://localhost:4318' -ServiceName 'backup' -ResourceAttributes @{ 'deployment.environment' = 'prod' } |
    Start-Logger
```

`service.name` and `deployment.environment` become Datadog's `service` and `env` tags.

### Splunk

Splunk Enterprise and Splunk Cloud Platform take logs through the HTTP Event Collector (HEC), not OTLP. Run the
Splunk Distribution of the OpenTelemetry Collector (or a plain collector with the `splunk_hec` exporter) next to the
script and send OTLP to it; the collector holds the HEC token:

```ps1
New-Logger | Add-SinkOpenTelemetry -Endpoint 'http://localhost:4318' -ServiceName 'backup' | Start-Logger
```

Without a collector, use [Add-SinkSplunk](Add-SinkSplunk.md) (PoShLog.Sinks.Splunk.Hec), which writes to HEC directly.

### Elastic

Elastic's managed OTLP endpoint (Elastic Cloud) and the APM Server accept OTLP/HTTP with an API key or a secret token:

```ps1
New-Logger |
    Add-SinkOpenTelemetry -Endpoint 'https://<deployment>.apm.<region>.cloud.es.io:443' -Headers @{ Authorization = 'ApiKey <api-key>' } -ServiceName 'backup' |
    Start-Logger
```

A self-managed APM Server listens on `http://<host>:8200`; with a secret token the header is
`Authorization = 'Bearer <token>'`. The Elastic Distribution of OpenTelemetry (EDOT) Collector on `:4318` works like
any collector. Writing straight into Elasticsearch data streams, without APM Server or a collector, is the planned
first-party module `PoShLog.Sinks.Elastic` (ADR 0009).

### OpenTelemetry Collector

Any backend the collector exports to (and many more than the ones above) is reached through a minimal receiver:

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
      grpc:
        endpoint: 0.0.0.0:4317
exporters:
  debug:
    verbosity: detailed
service:
  pipelines:
    logs:
      receivers: [otlp]
      exporters: [debug]
```

```ps1
New-Logger | Add-SinkOpenTelemetry | Start-Logger   # http://localhost:4318 by default
```

## OTLP or a dedicated sink?

| Backend | OTLP route | When a dedicated sink is better |
|---|---|---|
| Seq | Native (2024.1+) | Older Seq; Seq-specific CLEF and level control: `Add-SinkSeq`. |
| .NET Aspire | Native, the only route | - |
| Grafana Loki / Cloud | Native (Loki 3, OTLP gateway) | - |
| Datadog | Agent with OTLP ingest | No Agent on the machine: planned `PoShLog.Sinks.Datadog.Logs` (ADR 0009, later). |
| Splunk | Collector with HEC exporter | No collector: [Add-SinkSplunk](Add-SinkSplunk.md). |
| Elastic | APM Server, managed OTLP, EDOT Collector | Straight into data streams: planned `PoShLog.Sinks.Elastic`. |
| Syslog | None | Always: planned `PoShLog.Sinks.Syslog.Rfc5424`. |
