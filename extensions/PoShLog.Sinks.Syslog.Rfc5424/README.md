# PoShLog.Sinks.Syslog.Rfc5424

A syslog sink extension for PoShLog: RFC 5424 or RFC 3164 messages over UDP, TCP or TLS, formatted by
[Serilog.Sinks.SyslogMessages](https://github.com/IonxSolutions/serilog-sinks-syslog). Version 0.1.0 requires
PowerShell 7.4+ and PoShLog 2.99.0 (by GUID). Core supplies the shared Serilog assembly; `lib/` ships the formatter
assembly and the cmdlet.

Build from the repository root:

```powershell
./build/Build-Extension.ps1 -Module PoShLog.Sinks.Syslog.Rfc5424
Import-Module ./src/PoShLog.psd1
Import-Module ./extensions/PoShLog.Sinks.Syslog.Rfc5424/PoShLog.Sinks.Syslog.Rfc5424.psd1
New-Logger | Add-SinkSyslog -Hostname 'syslog.example.com' | Start-Logger
Write-InfoLog 'Hello from PoShLog'
Close-Logger
```

`Add-SinkSyslog` is a compiled cmdlet (`Cmdlets/`). `SyslogSinkSettings.cs` turns its parameters into the package's
formatter and framer; `SyslogTransport.cs` sends the messages over UDP or TCP with optional TLS, batched by Serilog.
The package's own sinks are not used: they need Serilog.Sinks.PeriodicBatching 5, which cannot load next to
PoShLog.Sinks.Seq 1.0.0. Parameters, TLS and the migration from the third-party PoShLog.Sinks.Syslog:
[docs/sinks/Add-SinkSyslog.md](../../docs/sinks/Add-SinkSyslog.md). Design:
[ADR 0014](../../docs/decisions/0014-syslog-sink-design.md).

Tests:
- `tests/PoShLog.Sinks.Syslog.Rfc5424.Tests`: xUnit, with loopback UDP, TCP and TLS receivers.
- `tests/PoShLog.Sinks.Syslog.Rfc5424.Tests.ps1`: Pester.
- The compatibility suite, which also loads the sink next to PoShLog.Sinks.Seq.
