@{
    RootModule = 'PoShLog.Sinks.MSSqlServer.psm1'
    ModuleVersion = '2.0.0'
    GUID = '554522a6-128c-4318-ac6e-07fe52f95c79'
    Author = 'Tomas Bouda'
    CompanyName = 'Tomas Bouda'
    Copyright = '(c) 2026 Tomas Bouda. All rights reserved.'
    Description = 'PoShLog extension for SQL Server and Azure SQL.
Writes batched events to SQL Server with isolated SqlClient dependencies and configurable columns.

Requires PowerShell 7.4+ and PoShLog 3.'
    PowerShellVersion = '7.4'
    CompatiblePSEditions = @('Core')
    RequiredModules = @(@{ ModuleName = 'PoShLog'; GUID = '6eabf344-4f00-4cc0-95d4-d3bef503e165'; ModuleVersion = '2.99.0' })
    FunctionsToExport = @()
    CmdletsToExport = @('Add-SinkMSSqlServer')
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{
        Prerelease = 'preview3'
        Tags = @('SQLServer', 'AzureSQL', 'Logging', 'Serilog', 'PSEdition_Core', 'Windows', 'Linux')
        LicenseUri = 'https://github.com/PoShLog/PoShLog/blob/master/LICENSE'
        ProjectUri = 'https://github.com/PoShLog/PoShLog/tree/master/extensions/PoShLog.Sinks.MSSqlServer'
        IconUri = 'https://raw.githubusercontent.com/PoShLog/PoShLog/master/docs/assets/icon.png'
        ReleaseNotes = 'https://github.com/PoShLog/PoShLog/blob/master/extensions/PoShLog.Sinks.MSSqlServer/CHANGELOG.md'
    } }
}

