# PoShLog.Sinks.Elastic

An Elasticsearch sink extension for PoShLog. It writes Elastic Common Schema (ECS) documents into data streams through
the bulk API, using [Elastic.Serilog.Sinks](https://github.com/elastic/ecs-dotnet). Version 0.1.0 requires PowerShell
7.6+ and PoShLog 3 (declared as 2.99.0 by GUID during the preview, ADR 0017). Core supplies the shared Serilog assembly; `lib/` ships the Elastic assemblies and the
cmdlet.

Build from the repository root:

```powershell
./build/Build-Extension.ps1 -Module PoShLog.Sinks.Elastic
Import-Module ./src/PoShLog.psd1
Import-Module ./extensions/PoShLog.Sinks.Elastic/PoShLog.Sinks.Elastic.psd1
New-Logger | Add-SinkElasticsearch -Node 'https://es.example.com:9200' -ApiKey $env:ES_API_KEY | Start-Logger
Write-InfoLog 'Hello from PoShLog'
Close-Logger
```

`Add-SinkElasticsearch` is a compiled cmdlet (`Cmdlets/`). `ElasticSinkSettings.cs` validates its parameters and turns
them into the package's sink, channel and transport options: a buffer that drops when full instead of blocking, and
SelfLog messages for failed and rejected requests. The psm1 compares file versions as well as assembly versions, because
Elastic.Channels, Elastic.Ingest.* and Elastic.Transport carry assembly version 0.0.0.0. Parameters, the document
fields and the migration from the third-party PoShLog.Sinks.Elasticsearch:
[docs/sinks/Add-SinkElasticsearch.md](../../docs/sinks/Add-SinkElasticsearch.md). Design:
[ADR 0015](../../docs/decisions/0015-elastic-sink-design.md).

Tests:
- `tests/PoShLog.Sinks.Elastic.Tests`: xUnit, with a loopback Elasticsearch stand-in.
- `tests/PoShLog.Sinks.Elastic.Tests.ps1`: Pester.
- The compatibility suite, which also loads the sink next to PoShLog.Sinks.Seq.
