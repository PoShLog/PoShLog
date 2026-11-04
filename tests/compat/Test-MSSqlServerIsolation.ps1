#Requires -Version 7.6
[CmdletBinding()]
param(
    [ValidateSet('DependencyFirst', 'SinkFirst')][string]$Order = 'DependencyFirst',
    [string]$ConflictAssembly = "$PSScriptRoot/fixtures/bin/Release/net10.0/Microsoft.Extensions.DependencyInjection.Abstractions.dll"
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
Import-Module "$root/src/PoShLog.psd1"
$conflict = [Reflection.AssemblyName]::GetAssemblyName((Resolve-Path $ConflictAssembly))
if ($conflict.Version -ne [version]'2.2.0.0') { throw 'Expected the real DI Abstractions 2.2.0.0 fixture.' }
function Import-Conflict {
    $script:foreign = [Runtime.Loader.AssemblyLoadContext]::Default.LoadFromAssemblyPath((Resolve-Path $ConflictAssembly))
    if (!$script:foreign.GetType('Microsoft.Extensions.DependencyInjection.IServiceCollection', $true)) { throw 'Cannot use foreign DI.' }
}
function Use-Sink {
    $diagnostics = [IO.StringWriter]::new()
    [Serilog.Debugging.SelfLog]::Enable([IO.TextWriter]::Synchronized($diagnostics))
    Import-Module "$root/extensions/PoShLog.Sinks.MSSqlServer/PoShLog.Sinks.MSSqlServer.psd1"
    $connection = if ($env:POSHLOG_SQL_CONNECTION_STRING) { $env:POSHLOG_SQL_CONNECTION_STRING } else {
        'Server=127.0.0.1,1;Database=master;Integrated Security=true;Connect Timeout=1'
    }
    $script:table = 'Isolation_' + [guid]::NewGuid().ToString('N')
    $config = New-Logger | Add-SinkMSSqlServer -ConnectionString $connection -TableName $script:table -AutoCreateSqlTable:([bool]$env:POSHLOG_SQL_CONNECTION_STRING)
    $config | Start-Logger
    if ($env:POSHLOG_SQL_CONNECTION_STRING) { Write-InfoLog 'Isolated SQL event {Number}' -PropertyValues 42 }
    Close-Logger
    $safe = $diagnostics.ToString().Replace($connection, '[connection]')
    if ($env:MSSQL_SA_PASSWORD) { $safe = $safe.Replace($env:MSSQL_SA_PASSWORD, '[credential]') }
    if ($safe) { [Console]::Error.WriteLine($safe) }
    [Serilog.Debugging.SelfLog]::Disable()
}
if ($Order -eq 'DependencyFirst') { Import-Conflict; Use-Sink } else { Use-Sink; Import-Conflict }
# Exercise the worker again after both assemblies are loaded, in either order.
Use-Sink
$context = [Runtime.Loader.AssemblyLoadContext]::All | Where-Object Name -eq 'PoShLog.Sinks.MSSqlServer'
if (!$context) { throw 'No private sink context.' }
$serilog = $context.LoadFromAssemblyName([Reflection.AssemblyName]::new('Serilog'))
if (![object]::ReferenceEquals($serilog, [Serilog.LoggerConfiguration].Assembly)) { throw 'Serilog is not shared with Core.' }
$diagnosticsAssembly = $context.LoadFromAssemblyName([Reflection.AssemblyName]::new('System.Diagnostics.DiagnosticSource'))
if (![object]::ReferenceEquals($diagnosticsAssembly, [System.Diagnostics.Activity].Assembly)) {
    throw 'DiagnosticSource is not shared with the host.'
}
if ([Runtime.Loader.AssemblyLoadContext]::GetLoadContext($foreign) -ne [Runtime.Loader.AssemblyLoadContext]::Default) {
    throw 'The conflicting assembly was not loaded in the default context.'
}
$private = $context.LoadFromAssemblyName([Reflection.AssemblyName]::new('Microsoft.Extensions.DependencyInjection.Abstractions'))
if ($private.GetName().Version -le $foreign.GetName().Version) { throw 'Private DI did not resolve independently.' }
if ([Runtime.Loader.AssemblyLoadContext]::GetLoadContext($private) -ne $context) { throw 'DI escaped the private context.' }
# This modern type does not exist in 2.2; force type resolution, not just file enumeration.
$null = $private.GetType('Microsoft.Extensions.DependencyInjection.IKeyedServiceProvider', $true)
foreach ($name in 'Microsoft.Data.SqlClient', 'Azure.Identity', 'Microsoft.Data.SqlClient.Extensions.Azure') {
    $assembly = $context.LoadFromAssemblyName([Reflection.AssemblyName]::new($name))
    if ([Runtime.Loader.AssemblyLoadContext]::GetLoadContext($assembly) -ne $context) { throw "$name escaped isolation." }
}
if ($env:POSHLOG_SQL_CONNECTION_STRING) {
    # Use SqlClient from the private context to read back the real event, without importing private types into PowerShell.
    $sql = $context.LoadFromAssemblyName([Reflection.AssemblyName]::new('Microsoft.Data.SqlClient'))
    $connection = [Activator]::CreateInstance($sql.GetType('Microsoft.Data.SqlClient.SqlConnection'), @($env:POSHLOG_SQL_CONNECTION_STRING))
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT COUNT(*) FROM [dbo].[$table] WHERE [Message] = 'Isolated SQL event 42' AND [Level] = 'Information'"
        if ($command.ExecuteScalar() -ne 1) {
            $command.CommandText = "SELECT [Level], [Message] FROM [dbo].[$table]"
            $reader = $command.ExecuteReader()
            while ($reader.Read()) { Write-Output "Received: [$($reader.GetString(0))] $($reader.GetString(1))" }
            $reader.Dispose()
            throw 'SQL readback failed.'
        }
    } finally { $connection.Dispose() }
    Write-Output "PASS SQL write/readback ($Order): Information, Isolated SQL event 42"
}
Write-Output "PASS isolation ($Order): default DI $($foreign.GetName().Version), private DI $($private.GetName().Version), shared Serilog"
