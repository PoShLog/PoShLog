# Add-SinkMSSqlServer

Writes batched events to SQL Server or Azure SQL. Requires the separately installed
[PoShLog.Sinks.MSSqlServer](../../extensions/PoShLog.Sinks.MSSqlServer/README.md), PowerShell 7.6+ and PoShLog 3
(Windows x64 or Linux x64).

```powershell
Install-PSResource PoShLog.Sinks.MSSqlServer -Prerelease
Import-Module PoShLog
Import-Module PoShLog.Sinks.MSSqlServer
New-Logger | Add-SinkMSSqlServer -ConnectionString $env:SQL_CONNECTION_STRING -AutoCreateSqlTable | Start-Logger
Write-InfoLog 'Processed order {OrderId}' -PropertyValues 42
Close-Logger
```

## Parameters

| Parameter | Default | Meaning |
|---|---|---|
| LoggerConfig | pipeline, required | Core's Serilog.LoggerConfiguration; returned for chaining |
| ConnectionString (alias cnn) | required | SqlClient connection string; supply from secure configuration |
| TableName | LogEvents | Destination table |
| SchemaName | dbo | Existing destination schema |
| AutoCreateSqlTable | off | Create the table if missing; requires DDL permissions |
| BatchPostingLimit | 50 | Positive maximum events per batch |
| BatchPeriod | 00:00:05 | Positive TimeSpan between batches |
| EagerlyEmitFirstEvent | true | Emit the first batch promptly; pass `$false` to disable |
| RestrictedToMinimumLevel | Verbose | Minimum event level for this sink |
| LevelSwitch | none | Shared LoggingLevelSwitch; overrides RestrictedToMinimumLevel |
| ColumnOptions | upstream defaults | Hashtable of column settings, shown below |
| Formatter | none | Shared Serilog ITextFormatter for the LogEvent column |
| FormatProvider | upstream default | IFormatProvider for message formatting |

The logger's minimum level also applies. Use Set-MinimumLevel to admit Debug/Verbose events.
Close-Logger flushes queued events. Auto-create does not create databases or schemas or migrate existing tables.
For production, provision the table separately and grant only required write permissions.

## Columns and JSON

Column options are data-only hashtables; scripts do not need SQL package types. Store replaces the standard columns.
Upstream defaults are Id, Message, MessageTemplate, Level, TimeStamp, Exception and Properties.
LogEvent is opt-in and contains full JSON; Properties is XML by default.

```powershell
$columns = @{
    Store = @('Id', 'Message', 'Level', 'TimeStamp', 'Exception', 'LogEvent')
    TimeStamp = @{ ConvertToUtc = $true }
    LogEvent = @{ ExcludeStandardColumns = $false }
    AdditionalColumns = @(
        @{ ColumnName = 'OrderId'; PropertyName = 'OrderId'; DataType = 'Int'; AllowNull = $true }
        @{ ColumnName = 'Customer'; PropertyName = 'Customer.Name'; DataType = 'NVarChar'; DataLength = 100 }
    )
}
New-Logger | Add-SinkMSSqlServer -ConnectionString $env:SQL_CONNECTION_STRING `
    -ColumnOptions $columns -BatchPostingLimit 100 -BatchPeriod ([timespan]::FromSeconds(2)) |
    Start-Logger
Write-InfoLog 'Processed order {OrderId}' -PropertyValues 42
Close-Logger
```

Standard column and SqlDbType names are case-insensitive. AdditionalColumns accepts one hashtable or an array.
PropertyName supports upstream hierarchical resolution. Nested settings use upstream ColumnOptions / SqlColumn
property names; unknown names fail during configuration. Types and lengths must match existing tables.
See the [upstream reference](https://github.com/serilog-mssql/serilog-sinks-mssqlserver#columnoptions-object).

## Migration from 1.0.0-preview1

ConnectionString/cnn, TableName, SchemaName, AutoCreateSqlTable, BatchPostingLimit, BatchPeriod,
RestrictedToMinimumLevel, Formatter and FormatProvider keep their names. The new module requires Core 3 and PowerShell
7.6; keep the old preview on PoShLog 2.x. Use PSResourceGet with -Prerelease during the preview.

Replace UseAzureManagedIdentity and AzureServiceTokenProviderResource with connection string authentication:
`Server=example.database.windows.net;Database=Logs;Authentication=Active Directory Managed Identity;Encrypt=true`.
For a user-assigned identity add `User ID=<client-id>`. The Azure authentication package is included; the old
AzureServiceTokenProvider is not loaded. Actual Azure authentication needs an appropriately configured environment.

The new module isolates SqlClient, Microsoft.Extensions and Azure assemblies from modules such as PnP.PowerShell.
Serilog stays shared with Core. Both import orders are tested against DI Abstractions 2.2.0.0. Upgrade when the new
module is released; the old Gallery preview is unchanged.

## Troubleshooting

Copy the whole module, including lib/private and runtimes. Individual DLL copies are insufficient.
Windows x64 includes native SNI; Linux x64 uses managed SNI. Keep encryption enabled and use a trusted server certificate.
TrustServerCertificate is only for the disposable local integration backend. Enable-SelfLog helps diagnose background
errors; review output before sharing it and never include a connection string in a bug report.
