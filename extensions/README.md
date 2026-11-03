# Building and checking extensions

Build Core before importing any extension:

```powershell
dotnet publish src/dotnet/PoShLog.Core.csproj -c Release -o src/lib --configfile build/nuget.config
./build/Build-Extension.ps1 -Module PoShLog.Sinks.Seq
./tests/compat/Invoke-Compatibility.ps1 -Mode InRepo
```

Run Build-Extension.ps1 for each of the six module directories before the compatibility suite.
The build restores only from nuget.org, stages publish output, and copies runtime dependencies
into lib/ while excluding Core's Serilog, File and Console assemblies. No binaries are committed.
Stage-Module.ps1 assembles a publishable module under artifacts/ from these outputs.

Each imported extension requires PoShLog >= 2.0.0 by GUID; PoShLog.Sinks.OpenTelemetry and PoShLog.Sinks.Splunk.Hec are new and require 3.0.0 (ADR 0004). The refreshed dependencies share Serilog 4
with v3 Core; the minimum preserves the v2 manifest contract, but does not guarantee that
every new sink package supports every v2 runtime. These refreshed releases require PowerShell 7.4+.

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
