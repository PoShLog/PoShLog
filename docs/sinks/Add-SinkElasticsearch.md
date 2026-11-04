### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.Elastic](../../extensions/PoShLog.Sinks.Elastic/README.md)
(PowerShell 7.6+, PoShLog 3.0.0+).

```ps1
Install-Module PoShLog.Sinks.Elastic
```

# Add-SinkElasticsearch `EXTENSION`

Sends log events to Elasticsearch or Elastic Cloud. Each event is stored as an Elastic Common Schema (ECS) document in a
data stream.

```ps1
Add-SinkElasticsearch
    [-LoggerConfig] <LoggerConfiguration>
    [-Node] <Uri[]>
    [-ApiKey <string>]
    [-Credential <PSCredential>]
    [-DataStream <string>]
    [-BootstrapMethod <BootstrapMethod>]
    [-IlmPolicy <string>]
    [-CertificateFingerprint <string>]
    [-FormatProvider <IFormatProvider>]
    [-ExcludeHost]
    [-ExcludeProcess]
    [-ExcludeUser]
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-LevelSwitch <LoggingLevelSwitch>]
    [-BatchInterval <TimeSpan>]
    [-BatchSizeLimit <int>]
    [-QueueLimit <int>]
    [<CommonParameters>]

Add-SinkElasticsearch
    [-LoggerConfig] <LoggerConfiguration>
    -CloudId <string>
    [-ApiKey <string>]
    [-Credential <PSCredential>]
    ... the same optional parameters ...
```

## Description

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.Elastic

New-Logger |
    Add-SinkElasticsearch -Node 'https://es.example.com:9200' -ApiKey $env:ES_API_KEY |
    Start-Logger

Write-WarningLog 'Backed up {Count} databases' -PropertyValues 12
Close-Logger
```

Events are batched and sent in the background through the bulk API. `Close-Logger` flushes what is still queued, so
call it before the script ends.

By default the documents go to the data stream `logs-poshlog-default`. The built-in `logs-*-*` index template of
Elasticsearch 8 and newer gives it its mappings and lifecycle, so no template has to be installed first. In Kibana, open
**Discover** and select the `logs-*` data view.

### Authentication

```ps1
# An API key, as the base64 "encoded" value Kibana shows when the key is created.
New-Logger | Add-SinkElasticsearch 'https://es.example.com:9200' -ApiKey $env:ES_API_KEY | Start-Logger

# A user name and password (basic authentication).
New-Logger | Add-SinkElasticsearch 'https://es.example.com:9200' -Credential (Get-Credential) | Start-Logger

# Elastic Cloud, by the deployment's Cloud ID.
New-Logger | Add-SinkElasticsearch -CloudId $env:ES_CLOUD_ID -ApiKey $env:ES_API_KEY | Start-Logger
```

An API key only needs the `create_doc` and `auto_configure` privileges on the data stream, such as `logs-poshlog-*`.

### A self-signed certificate

Elasticsearch 8 creates its own CA when it is installed. Pass that CA's SHA-256 fingerprint to trust it without adding
it to the system's trust store. The fingerprint is printed at the first start, or you can read it from the CA:

```ps1
# openssl x509 -fingerprint -sha256 -noout -in config/certs/http_ca.crt
New-Logger |
    Add-SinkElasticsearch 'https://localhost:9200' -ApiKey $env:ES_API_KEY -CertificateFingerprint $env:ES_CA_SHA256 |
    Start-Logger
```

There is no switch that turns certificate validation off.

### Data streams and templates

`-DataStream` takes a name in the form `type-dataset-namespace`, lowercase, with no `-` inside a part, such as
`logs-backup-prod`. Use a name per application to keep its logs apart.

A name that matches no index template on the cluster gets dynamic mappings. Use `-BootstrapMethod Silent` to install
Elastic's ECS templates for the stream first. `Failure` does the same but stops the logger when the installation fails.
The bootstrap needs the `manage_index_templates` cluster privilege. `-IlmPolicy` names the lifecycle
policy those templates use; it applies only with a bootstrap.

## The document

A `Write-WarningLog 'Backed up {Count} databases for {User}' -PropertyValues 12, 'tomas'` call stores a document like
this one (shortened):

```json
{
  "@timestamp": "2026-11-03T10:15:30.123+00:00",
  "log.level": "Warning",
  "message": "Backed up 12 databases for \"tomas\"",
  "ecs.version": "9.0.0",
  "labels": { "MessageTemplate": "Backed up {Count} databases for {User}", "User": "tomas" },
  "metadata": { "Count": 12 },
  "event": { "severity": 3 },
  "host": { "hostname": "web01", "os": { "platform": "Win32NT" } },
  "process": { "pid": 9100, "name": "pwsh" },
  "user": { "name": "tomas", "domain": "WEB01" },
  "service": { "name": "pwsh", "type": "dotnet" }
}
```

- String properties go to `labels`, next to the message template. Numbers and structured values (`{@Obj}`) go to
  `metadata`.
- An exception goes to `error.type`, `error.message` and `error.stack_trace`.
- `-ExcludeHost`, `-ExcludeProcess` and `-ExcludeUser` leave out the `host`, `process` and `user` fields. Use them when
  the machine or account name must not reach the cluster.

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `-Node` | required | URL of one or more nodes, such as `https://es.example.com:9200`. Aliases `-Uri`, `-Nodes`. |
| `-CloudId` | required | Cloud ID of an Elastic Cloud deployment, instead of `-Node`. Needs `-ApiKey` or `-Credential`. |
| `-ApiKey` | none | The encoded API key. Not together with `-Credential`. |
| `-Credential` | none | User name and password for basic authentication. |
| `-DataStream` | `logs-poshlog-default` | Target data stream, `type-dataset-namespace`. |
| `-BootstrapMethod` | `None` | `None`, `Silent` or `Failure`: whether index templates are installed first. |
| `-IlmPolicy` | Elastic's default | Lifecycle policy for the installed templates. Needs `-BootstrapMethod Silent` or `Failure`. |
| `-CertificateFingerprint` | none | SHA-256 fingerprint of the CA or server certificate to trust. Alias `-CaFingerprint`. |
| `-FormatProvider` | current culture | Culture used for rendering the message. |
| `-ExcludeHost`, `-ExcludeProcess`, `-ExcludeUser` | off | Leave those ECS field groups out of the documents. |
| `-RestrictedToMinimumLevel` | `Verbose` | Lowest level this sink receives. |
| `-LevelSwitch` | none | A `LoggingLevelSwitch` that changes the sink's level at run time. |
| `-BatchInterval` | 2 seconds | How long events are buffered before they are sent, at least 1 second. A number means seconds (`-BatchInterval 1.5`). |
| `-BatchSizeLimit` | 1000 | Maximum documents per bulk request. |
| `-QueueLimit` | 100000 | Maximum events waiting to be sent; later events are dropped. |

## Delivery and errors

- A failed request is retried with back-off; the events are then dropped. Turn on `Enable-SelfLog` to see why: a
  refused connection, failed authentication, an untrusted certificate, an error status, or a document the cluster
  rejected (a mapping conflict, for example).
- Before the first request, the client checks that the server is Elasticsearch. A proxy that does not pass the
  `X-Elastic-Product` response header through makes every request fail.
- A full queue drops new events instead of making `Write-*Log` wait for the cluster.
- `-BatchInterval` below one second is an error, because the Elastic client would ignore it and wait five seconds.

## Migrating from PoShLog.Sinks.Elasticsearch

PoShLog.Sinks.Elasticsearch (mamidenn) is another author's module for Windows PowerShell, built on the retired
Serilog.Sinks.Elasticsearch. It writes to classic indices; this module writes to data streams.

| PoShLog.Sinks.Elasticsearch 1.0.0-alpha5 | PoShLog.Sinks.Elastic | Note |
|---|---|---|
| `Add-SinkElasticsearch` | same | |
| `-Uri` | `-Node` (alias `-Uri`) | |
| `-IndexFormat 'logs-{0:yyyy.MM.dd}'` | `-DataStream 'logs-myapp-default'` | Data streams roll over by lifecycle, not by date in the name. |
| `-AutoRegisterTemplate` | `-BootstrapMethod Silent` | Not needed for a `logs-` stream on Elasticsearch 8 and newer. |
| `-AutoRegisterTemplateVersion` | none | The templates follow ECS 9. |
| `-SkipServerCertificateCheck` | `-CertificateFingerprint` | Trust the cluster's CA instead of any certificate. |

The third-party module runs only in Windows PowerShell 5.1, and this module only in PowerShell 7.6 and newer, so they
never load into the same session. Kibana searches that read the old index fields (`fields.*`, `level`) need the ECS
names (`labels.*`, `log.level`).
