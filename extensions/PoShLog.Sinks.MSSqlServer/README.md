# PoShLog.Sinks.MSSqlServer

Writes batched events to SQL Server and Azure SQL, with private SqlClient dependencies that coexist with other modules.
Requires PowerShell 7.6+ and PoShLog 3; supports Windows x64 and Linux x64.

```powershell
Install-PSResource PoShLog.Sinks.MSSqlServer -Prerelease
Import-Module PoShLog
Import-Module PoShLog.Sinks.MSSqlServer
New-Logger |
    Add-SinkMSSqlServer -ConnectionString $env:SQL_CONNECTION_STRING -TableName LogEvents -AutoCreateSqlTable |
    Start-Logger
Write-InfoLog 'Processed {Count} items' -PropertyValues 42
Close-Logger
```

Supply connection strings through secure configuration. Auto-create needs table creation permissions; provision tables
separately for production. Close-Logger flushes pending batches. The [sink guide](../../docs/sinks/Add-SinkMSSqlServer.md)
covers columns, batching, levels and migration.

Version 2.0.0-preview3 refreshes 1.0.0-preview1 for Core 3. The major reflects the new runtime requirement; preview3 matches
the next Core preview (ADRs 0004, 0019). PoShLog 2.x users stay on the old preview.

## Building

Run from the repository root:

```powershell
./build/Build-Core.ps1
./build/Build-Extension.ps1 -Module PoShLog.Sinks.MSSqlServer
./build/Stage-Module.ps1 -Module PoShLog.Sinks.MSSqlServer
```

The entry DLL is thin; lib/private contains the worker, dependency metadata, package DLLs and runtime assets.
Copy the entire staged module. Linux uses managed SNI; Windows includes native SNI. Do not flatten the folders or
Add-Type private DLLs. Serilog stays shared with Core; SqlClient, Microsoft.Extensions and Azure dependencies load
privately ([ADR 0030](../../docs/decisions/0030-mssqlserver-private-dependencies.md)).
