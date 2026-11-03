# Changelog

## 0.1.0-preview2 — 2026-11-03

### Features
- New `Add-SinkElasticsearch` sends log events to Elasticsearch nodes (`-Node`) or Elastic Cloud (`-CloudId`) as
  Elastic Common Schema documents.
- Writes into the data stream `logs-poshlog-default` by default; `-DataStream` picks another one.
- Authentication by API key (`-ApiKey`) or user name and password (`-Credential`).
- `-CertificateFingerprint` trusts a self-signed CA, such as the one Elasticsearch 8 generates, by its SHA-256
  fingerprint.
- `-BootstrapMethod Silent|Failure` installs Elastic's ECS index templates first; `-IlmPolicy` names their lifecycle
  policy.
- `-ExcludeHost`, `-ExcludeProcess` and `-ExcludeUser` leave those fields out of the documents.
- Batching with `-BatchInterval`, `-BatchSizeLimit` and `-QueueLimit`; a level filter and a level switch.
- `Enable-SelfLog` shows why events do not arrive: failed connections and authentication, error responses, rejected
  documents.

### Changes
- Requires PoShLog 2.99.0 and PowerShell 7.4 or newer.
- Replaces the third-party PoShLog.Sinks.Elasticsearch for PowerShell 7; `-Uri` still works as an alias of `-Node`.
- A full queue drops new events instead of blocking the script, as in the other PoShLog sinks.

### Bug fixes
- A `-BatchInterval` under one second is an error; the Elastic client silently waited five seconds instead.
