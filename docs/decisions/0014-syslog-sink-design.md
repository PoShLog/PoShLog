# 0014 — The Syslog sink: the package's formatters, our own transports

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Builds on:** [0009](0009-first-party-sinks-third-party-check-non-blocking.md) (name and scope),
  [0011](0011-core-does-not-load-assemblies-extensions-ship.md), [0012](0012-otlp-sink-design.md) (module layout),
  [0013](0013-splunk-hec-sink-design.md) (the `foreach` loader)

## Context

ADR 0009 calls for a first-party syslog sink. The Gallery name `PoShLog.Sinks.Syslog` belongs to another author's
module (1.0.0, a script wrapper over Serilog.Sinks.SyslogMessages 1.0.5 with `Add-SinkSyslogUdp`, `Add-SinkSyslogTcp`
and `Add-SinkSyslogLocal`), so this one is `PoShLog.Sinks.Syslog.Rfc5424`.

Serilog.Sinks.SyslogMessages 4.1.0, the current package (assembly `Serilog.Sinks.Syslog`), constrains the design:

- Its UDP and TCP sinks implement `IBatchedLogEventSink` from Serilog.Sinks.PeriodicBatching 5.0.0. The published
  PoShLog.Sinks.Seq 1.0.0 ships PeriodicBatching 2.x. One process cannot load both versions into the default load
  context, so a module that ships PeriodicBatching 5 fails next to Seq 1.0.0 in one import order or the other.
- The package stamps every release with assembly version 0.0.0.0; only the file version (4.1.0.0) tells releases apart.
- Its default severity mapping puts Verbose at Notice, above Information, and Fatal at Emergency, which the default
  rsyslog configuration of Debian and Red Hat broadcasts to every logged-in terminal.
- Its RFC 5424 formatter writes an invalid structured data element (`[ Count="1"]`) when no SD-ID is given.
- `{NewLine}` at the end of an output template leaves a line break in every message, which a line-framed TCP stream
  reads as an empty message.
- A `RemoteCertificateValidationCallback` made from a PowerShell script block runs on a thread without a runspace.

## Decision

`Add-SinkSyslog` is a compiled cmdlet in the OTLP sink's layout (ADR 0012). It uses only the package's
`Rfc5424Formatter`, `Rfc3164Formatter` and `MessageFramer`, which do not touch PeriodicBatching. The transports are our
own: `SyslogUdpTransport` and `SyslogTcpTransport` implement Serilog 4's `Serilog.Core.IBatchedLogEventSink` and run
under `BatchingOptions`. PeriodicBatching is referenced for compilation only and is not in `lib/`.

- **Defaults.** RFC 5424 over UDP, port 514 for Udp and Tcp, 6514 for TcpTls (RFC 5425), octet counting on TCP
  (RFC 6587), facility Local0, the SD-ID `poshlog@32473` (32473 is the enterprise number reserved for documentation,
  RFC 5612), APP-NAME from the calling script's file name, message template `{Message:lj}{NewLine}{Exception}` with
  trailing line breaks trimmed.
- **Severity.** Our own mapping: Verbose and Debug to Debug, Information to Informational, Warning to Warning, Error
  to Error, Fatal to Critical.
- **TLS.** `-TrustedCertificateThumbprint` pins a server certificate by its SHA-1 or SHA-256 thumbprint on top of the
  system's trust decision: the way to trust a self-signed syslog server from a script. `-CertificateValidationCallback`
  stays for compiled delegates.
- **Validation.** An option the chosen protocol or format would ignore is an error: `-Framing` with Udp, certificate
  options without TcpTls, `-StructuredDataId` and `-MessageIdPropertyName` with Rfc3164. An invalid SD-ID is an error.
- **Loading.** The psm1 compares file versions when assembly versions are equal and refuses to import after a module
  that loaded an older Serilog.Sinks.Syslog, such as the third-party PoShLog.Sinks.Syslog.
- **No aliases** for `Add-SinkSyslogUdp` and `Add-SinkSyslogTcp`: one command with `-Protocol` replaces them, and the
  docs page carries a migration table.

## Alternatives considered

- **Wrap the package's `UdpSyslogSink` and `TcpSyslogSink`.** Less code, but `lib/` would ship PeriodicBatching 5.0.0
  and the module would fail next to PoShLog.Sinks.Seq 1.0.0, the most installed PoShLog extension.
- **A custom AssemblyLoadContext for PeriodicBatching and the package.** It needs a resolver that sends every Serilog
  type back to the default context Core loads (ADR 0011), and one more loading scheme to keep working across
  PowerShell versions. Two small transports are less to maintain.
- **Aliases or wrapper functions named `Add-SinkSyslogUdp` and `Add-SinkSyslogTcp`.** They would clash with the
  third-party module's exports, and its TCP defaults (port 1468, `-FramingType`, `-SecureProtocols`) do not map cleanly.
- **RFC 3164 as the default, as in the third-party UDP command.** RFC 3164 has no structured data, no year and no time
  zone. rsyslog, syslog-ng and current collectors parse RFC 5424.
- **Our own formatters.** The package's formatters handle priority, header escaping and SD-PARAM escaping and are
  maintained; three small fixes (an explicit SD-ID, trimmed line
  breaks, a severity mapping) are enough.

## Consequences

- The `lib/` folder ships only `Serilog.Sinks.Syslog.dll` and the cmdlet assembly.
- Batching, retries and back-off come from Serilog 4. UDP is fire-and-forget; a datagram above 65507 bytes is cut at a
  UTF-8 character boundary.
- The module cannot load in a session after the third-party PoShLog.Sinks.Syslog. The docs page says to import only
  one, and the psm1 says why when it refuses.
- The compatibility suite runs the module alone and next to Seq in both import orders, with the refreshed Seq and with
  Seq 1.0.0.
- The Gallery name `PoShLog.Sinks.Syslog.Rfc5424` was free on 2026-11-03. Tomáš confirms it before the first publish
  (ADR 0009).
- No real rsyslog or syslog-ng server was used for testing. Loopback UDP, TCP and TLS receivers
  (`tests/PoShLog.Sinks.Syslog.Rfc5424.Tests`) check the messages and the framing.
