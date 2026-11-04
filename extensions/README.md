# Building and checking extensions

Build Core before importing any extension:

```powershell
dotnet publish src/dotnet/PoShLog.Core.csproj -c Release -o src/lib --configfile build/nuget.config
./build/Build-Extension.ps1 -Module PoShLog.Sinks.Seq
./tests/compat/Invoke-Compatibility.ps1 -Mode InRepo
```

Run Build-Extension.ps1 for each of the nine module directories before the compatibility suite.
The build restores only from nuget.org, stages publish output, and copies runtime dependencies
into lib/ while excluding Core's Serilog, File and Console assemblies. No binaries are committed.
Stage-Module.ps1 assembles a publishable module under artifacts/ from these outputs.

Each imported extension requires PoShLog by GUID: the refreshed Seq, EventLog, Http and Enrichers 2.0.0 and the new
OpenTelemetry, Splunk.Hec, Syslog.Rfc5424 and Elastic sinks require PoShLog 3 (ADR 0004), declared as 2.99.0 while Core 3 is a
prerelease (ADR 0017). They share Serilog 4 with v3 Core and require PowerShell 7.6+. PoShLog 2.x users stay on the
published 1.0.x versions. The full table is in docs/compatibility.md.

## Source provenance

Only committed git blobs were imported. The original working trees were not copied or modified.

| Module | Original repository | Revision |
|---|---|---|
| PoShLog.Sinks.Seq | PoShLog/PoShLog.Sinks.Seq | 7ee344d |
| PoShLog.Sinks.EventLog | PoShLog/PoShLog.Sinks.EventLog | 460862d |
| PoShLog.Enrichers | PoShLog/PoShLog.Enrichers | dbaf947 |
| PoShLog.Sinks.Http | PoShLog/PoShLog.Sinks.Http2 | dda3b53 (origin/master) |

The old src/ directory is flattened into each module directory. Http retains its compiled
Get-ApiKeyHttpClient command and the published binary module's GUID from Metadata/.
Its Add-SinkHttp wrapper uses Serilog 4 batching to preserve QueueLimit as an event count;
Http 9's own queue limit is in bytes. Its client also retains the earlier HttpContent overload.
Seq retains the Compact parameter through the new payload formatter API.

PoShLog.Sinks.OpenTelemetry was written here, not imported. Its cmdlet is compiled from Dependencies.csproj, and its
psm1 reuses Protobuf and gRPC assemblies another module already loaded (ADR 0012).

PoShLog.Sinks.Splunk.Hec was written here the same way. Its psm1 reuses a loaded Serilog.Sinks.Splunk of the same or a
newer version and refuses to import next to an older one, such as the third-party module's 3.7.0 (ADR 0013).

PoShLog.Sinks.Syslog.Rfc5424 was written here too. It uses only the formatters of Serilog.Sinks.SyslogMessages and
sends through its own transports, so it ships no Serilog.Sinks.PeriodicBatching. Its psm1 compares file versions,
because every release of that package has assembly version 0.0.0.0 (ADR 0014).

PoShLog.Sinks.Elastic was written here too, on Elastic.Serilog.Sinks. Its psm1 compares file versions in the same way,
because Elastic.Channels, Elastic.Ingest.* and Elastic.Transport have assembly version 0.0.0.0. The sink drops new
events when its queue is full, where the package would block the script (ADR 0015).

PoShLog.Sinks.MSSqlServer 2.0.0-preview3 refreshes the old SQL extension. Its thin cmdlet shares Core's Serilog and
the host's DiagnosticSource, and loads SqlClient, Microsoft.Extensions and Azure packages in a private context
(ADR 0030). Build-Extension preserves the worker's deps.json and runtime asset folders; never flatten lib/private.
