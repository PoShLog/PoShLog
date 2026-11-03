# PoShLog.Sinks.Splunk.Hec

A Splunk HTTP Event Collector (HEC) sink extension for PoShLog over
[Serilog.Sinks.Splunk](https://github.com/serilog-contrib/serilog-sinks-splunk). Version 0.1.0 requires PowerShell 7.4+
and PoShLog 2.99.0 (by GUID). Core supplies the shared Serilog assembly; `lib/` ships the sink.

Build from the repository root:

```powershell
./build/Build-Extension.ps1 -Module PoShLog.Sinks.Splunk.Hec
Import-Module ./src/PoShLog.psd1
Import-Module ./extensions/PoShLog.Sinks.Splunk.Hec/PoShLog.Sinks.Splunk.Hec.psd1
New-Logger | Add-SinkSplunk -Url 'https://splunk.example.com:8088' -Token $env:SPLUNK_HEC_TOKEN -Index 'main' | Start-Logger
Write-InfoLog 'Hello from PoShLog'
Close-Logger
```

`Add-SinkSplunk` is a compiled cmdlet (`Cmdlets/`). `SplunkHecSinkSettings.cs` turns its parameters into the request
target and the payload formatter: Splunk JSON on the event endpoint, text lines on the raw endpoint. Parameters, the
raw endpoint and the migration from the third-party PoShLog.Sinks.Splunk:
[docs/sinks/Add-SinkSplunk.md](../../docs/sinks/Add-SinkSplunk.md). Design:
[ADR 0013](../../docs/decisions/0013-splunk-hec-sink-design.md).

Tests:
- `tests/PoShLog.Sinks.Splunk.Hec.Tests`: xUnit, with a local HEC stand-in.
- `tests/PoShLog.Sinks.Splunk.Hec.Tests.ps1`: Pester.
- The compatibility suite, which also loads the sink next to PoShLog.Sinks.Seq.
