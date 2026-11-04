# Changelog

## Unreleased

### Features
- No new features.

### Changes
- Requires PowerShell 7.6 or newer and is built for .NET 10 (ADR 0033). This is a breaking change on PowerShell 7.4 and 7.5: stay on the previous version there, or on PoShLog 2.x with the 1.0.x extensions.

### Bug fixes
- None.

## 0.1.0-preview2 — 2026-11-03

### Features
- New `Add-SinkSyslog` sends log events to a syslog server over UDP, TCP or TLS (`-Protocol Udp|Tcp|TcpTls`).
- RFC 5424 messages by default, with the event's properties as structured data and `SourceContext` as MSGID;
  `-Format Rfc3164` for older receivers.
- TCP framing by octet counting (default) or a delimiter (`-Framing Lf|CrLf|Cr|Nul`).
- `-TrustedCertificateThumbprint` trusts a self-signed server certificate by its SHA-1 or SHA-256 thumbprint;
  `-ClientCertificate` for mutual TLS.
- `-AppName` defaults to the calling script's name; `-Facility`, `-SourceHost`, `-OutputTemplate`.
- Batching with `-BatchInterval`, `-BatchSizeLimit` and `-QueueLimit`; a level filter and a level switch.

### Changes
- Requires PoShLog 2.99.0 and PowerShell 7.4 or newer.
- One command replaces `Add-SinkSyslogUdp` and `Add-SinkSyslogTcp` of the third-party PoShLog.Sinks.Syslog.
- Fatal events are sent as Critical, not Emergency, and Verbose events as Debug, not Notice.
- An option that the chosen protocol or format would ignore is an error.

### Bug fixes
- RFC 5424 messages carry a valid SD-ID (`poshlog@32473` by default); the package left it empty.
- A message no longer ends with an empty line, which line-framed TCP receivers read as a second message.
