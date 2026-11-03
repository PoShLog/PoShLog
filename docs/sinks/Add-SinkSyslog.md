### Dependencies

This cmdlet requires the extension module [PoShLog.Sinks.Syslog.Rfc5424](../../extensions/PoShLog.Sinks.Syslog.Rfc5424/README.md)
(PowerShell 7.4+, PoShLog 3.0.0+).

```ps1
Install-Module PoShLog.Sinks.Syslog.Rfc5424
```

# Add-SinkSyslog `EXTENSION`

Sends log events to a syslog server (rsyslog, syslog-ng, a SIEM collector) over UDP, TCP or TLS, as RFC 5424 or
RFC 3164 messages.

```ps1
Add-SinkSyslog
    [-LoggerConfig] <LoggerConfiguration>
    [-Hostname] <string>
    [-Port <int>]
    [-Protocol <SyslogProtocol>]
    [-Format <SyslogMessageFormat>]
    [-Framing <SyslogFraming>]
    [-AppName <string>]
    [-Facility <Facility>]
    [-SourceHost <string>]
    [-MessageIdPropertyName <string>]
    [-StructuredDataId <string>]
    [-OutputTemplate <string>]
    [-FormatProvider <IFormatProvider>]
    [-ClientCertificate <X509Certificate[]>]
    [-TrustedCertificateThumbprint <string[]>]
    [-CertificateValidationCallback <RemoteCertificateValidationCallback>]
    [-RestrictedToMinimumLevel <LogEventLevel>]
    [-LevelSwitch <LoggingLevelSwitch>]
    [-BatchInterval <TimeSpan>]
    [-BatchSizeLimit <int>]
    [-QueueLimit <int>]
    [<CommonParameters>]
```

## Description

```ps1
Import-Module PoShLog
Import-Module PoShLog.Sinks.Syslog.Rfc5424

New-Logger |
    Add-SinkSyslog -Hostname 'syslog.example.com' |
    Start-Logger

Write-WarningLog 'Backed up {Count} databases' -PropertyValues 12
Close-Logger
```

Events are batched and sent in the background. `Close-Logger` flushes what is still queued, so call it before the
script ends.

### RFC 5424 (default)

Each event becomes one RFC 5424 message. Its properties travel as structured data, and the event's `SourceContext`
becomes the MSGID:

```text
<132>1 2026-11-03T10:15:30.000000+00:00 web01 nightly-backup 9100 - [poshlog@32473 Count="12"] Backed up 12 databases
```

- The priority is the facility (`Local0` by default) times 8 plus the severity: Verbose and Debug map to Debug (7),
  Information to Informational (6), Warning to Warning (4), Error to Error (3) and Fatal to Critical (2). Emergency
  is left out on purpose: rsyslog's default rules broadcast it to every logged-in terminal.
- APP-NAME is the calling script's file name (`nightly-backup.ps1` becomes `nightly-backup`), otherwise the process
  name.
- HOSTNAME is the machine name; `-SourceHost` sets another.
- The SD-ID `poshlog@32473` uses the enterprise number reserved for documentation (RFC 5612). If your collector filters
  on an SD-ID, set your own with `-StructuredDataId 'backup@<your PEN>'`.
- An exception follows the message on the next lines. String values are not quoted (`{Message:lj}`).

### RFC 3164

`-Format Rfc3164` writes the older BSD format, for receivers that do not parse RFC 5424. It has no structured data,
no year and no time zone:

```text
<132>Nov  3 10:15:30 web01 nightly-backup[9100]: Backed up 12 databases
```

### TCP and TLS

```ps1
# Plain TCP, octet-counted frames (RFC 6587), port 514.
New-Logger | Add-SinkSyslog 'syslog.example.com' -Protocol Tcp | Start-Logger

# TLS (RFC 5425), port 6514, the server certificate validated against the system's trust store.
New-Logger | Add-SinkSyslog 'syslog.example.com' -Protocol TcpTls | Start-Logger

# A self-signed server certificate, trusted by its SHA-256 (or SHA-1) thumbprint.
New-Logger |
    Add-SinkSyslog 'syslog.example.com' -Protocol TcpTls -TrustedCertificateThumbprint $env:SYSLOG_CERT_SHA256 |
    Start-Logger
```

Use `-Framing Lf` for a receiver that splits a TCP stream on line feeds. Pass `-ClientCertificate` when the server
requires mutual TLS.

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| `-Hostname` | required | Name or IP address of the syslog server. A name resolves to its first IPv4 address when it has one. |
| `-Port` | 514, TcpTls 6514 | Server port. |
| `-Protocol` | `Udp` | `Udp` (one datagram per message), `Tcp` or `TcpTls`. |
| `-Format` | `Rfc5424` | `Rfc5424` or `Rfc3164`. |
| `-Framing` | `OctetCounting` | `OctetCounting`, `Lf`, `CrLf`, `Cr` or `Nul`. Tcp and TcpTls only. |
| `-AppName` | script name | The APP-NAME (RFC 5424) or TAG (RFC 3164) field. |
| `-Facility` | `Local0` | Syslog facility, such as `User`, `Daemons`, `Auth` or `Local0` to `Local7`. |
| `-SourceHost` | machine name | The HOSTNAME field. |
| `-MessageIdPropertyName` | `SourceContext` | Event property written as MSGID. Rfc5424 only. |
| `-StructuredDataId` | `poshlog@32473` | SD-ID of the element that carries the properties. Rfc5424 only. |
| `-OutputTemplate` | `{Message:lj}{NewLine}{Exception}` | The MSG text. Trailing line breaks are dropped. |
| `-FormatProvider` | current culture | Culture used for rendering the message. |
| `-ClientCertificate` | none | Client certificates for mutual TLS. TcpTls only. |
| `-TrustedCertificateThumbprint` | none | SHA-1 or SHA-256 thumbprints of server certificates to trust in addition to the system's trust store. TcpTls only. |
| `-CertificateValidationCallback` | system | A compiled validation delegate. Alias `-CertValidationCallback`. TcpTls only; not together with `-TrustedCertificateThumbprint`. |
| `-RestrictedToMinimumLevel` | `Verbose` | Lowest level this sink receives. |
| `-LevelSwitch` | none | A `LoggingLevelSwitch` that changes the sink's level at run time. |
| `-BatchInterval` | 2 seconds | How long events are buffered before they are sent. A number means seconds (`-BatchInterval 0.5`). |
| `-BatchSizeLimit` | 100 | Maximum events per batch. |
| `-QueueLimit` | 100000 | Maximum events waiting to be sent; later events are dropped. |

An option that the chosen protocol or format would ignore, such as `-Framing` with UDP, is an error.

## Delivery and errors

- **UDP** is fire-and-forget: a server that is down or a firewall that drops the datagrams goes unnoticed. A message
  above 65507 bytes is cut at a character boundary. Use TCP or TLS when messages must arrive.
- **TCP and TLS** connect on the first batch and keep the connection open. A failed connection or write is retried with
  back-off for up to ten minutes; the batch is then dropped. Turn on `Enable-SelfLog` to see the reason.
- **TLS** validates the server certificate and its name against `-Hostname`. Do not pass a callback that always
  returns `$true`; pin the certificate with `-TrustedCertificateThumbprint` instead. A PowerShell script block used as
  a callback would run on a thread without a runspace.

## Migrating from PoShLog.Sinks.Syslog

PoShLog.Sinks.Syslog (Michael Zimmerli) is another author's module on Serilog.Sinks.SyslogMessages 1.0.5. One command
with `-Protocol` replaces its two network commands:

| PoShLog.Sinks.Syslog 1.0.0 | PoShLog.Sinks.Syslog.Rfc5424 | Note |
|---|---|---|
| `Add-SinkSyslogUdp` | `Add-SinkSyslog` | UDP is the default protocol. |
| `Add-SinkSyslogTcp` | `Add-SinkSyslog -Protocol Tcp` | `-Protocol TcpTls` for TLS. |
| `Add-SinkSyslogLocal` | none | Send to the local daemon over UDP instead: `Add-SinkSyslog 127.0.0.1`. |
| `-Format RFC3164` (UDP default) | `-Format Rfc3164` | The default is now `Rfc5424`. |
| `-FramingType OCTET_COUNTING` | `-Framing OctetCounting` | Same default. |
| TCP port 1468 by default | 514 (Tcp), 6514 (TcpTls) | Pass `-Port 1468` to keep the old port. |
| `-SecureProtocols`, `-CertProvider` | `-Protocol TcpTls`, `-ClientCertificate` | TLS versions follow the operating system. |
| `-CertValidationCallback` | same (alias) | Or `-TrustedCertificateThumbprint`. |
| `-Hostname`, `-Port`, `-AppName`, `-Facility`, `-OutputTemplate`, `-RestrictedToMinimumLevel` | same | |

Import only one of the two modules into a session. Both ship Serilog.Sinks.Syslog.dll in different versions, and one
process can load only one of them. PoShLog.Sinks.Syslog.Rfc5424 refuses to import after the other module and says why.
