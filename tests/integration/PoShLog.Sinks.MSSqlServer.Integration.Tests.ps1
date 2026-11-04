if ($env:POSHLOG_INTEGRATION -ne '1') { return }
BeforeAll {
    . "$PSScriptRoot/Helpers.ps1"
    Import-Module PoShLog.Sinks.MSSqlServer
    if (!$env:POSHLOG_SQL_CONNECTION_STRING) { throw 'Set POSHLOG_SQL_CONNECTION_STRING for the disposable SQL backend.' }
}
Describe 'SQL Server delivery through the isolated worker' {
    BeforeEach {
        $script:diagnostics = [IO.StringWriter]::new()
        [Serilog.Debugging.SelfLog]::Enable([IO.TextWriter]::Synchronized($script:diagnostics))
    }
    It 'creates a table, flushes batches and reads levels, messages, JSON and additional columns' {
        $id = [guid]::NewGuid().ToString('N')
        $table = "Events_$id"
        $columns = @{
            Store = @('Id', 'Message', 'MessageTemplate', 'Level', 'TimeStamp', 'Exception', 'Properties', 'LogEvent')
            AdditionalColumns = @(@{ ColumnName = 'Number'; PropertyName = 'Number'; DataType = 'Int' })
        }
        New-Logger | Set-MinimumLevel -Value Verbose |
            Add-SinkMSSqlServer -ConnectionString $env:POSHLOG_SQL_CONNECTION_STRING -TableName $table `
            -AutoCreateSqlTable -BatchPostingLimit 2 -BatchPeriod ([timespan]::FromMilliseconds(100)) `
            -RestrictedToMinimumLevel Information -ColumnOptions $columns | Start-Logger
        Write-DebugLog 'This event must be filtered'
        Write-IntegrationEvents $id
        $context = [Runtime.Loader.AssemblyLoadContext]::All | Where-Object Name -eq 'PoShLog.Sinks.MSSqlServer'
        $sql = $context.LoadFromAssemblyName([Reflection.AssemblyName]::new('Microsoft.Data.SqlClient'))
        $connection = [Activator]::CreateInstance($sql.GetType('Microsoft.Data.SqlClient.SqlConnection'), @($env:POSHLOG_SQL_CONNECTION_STRING))
        try {
            $connection.Open()
            $command = $connection.CreateCommand()
            $command.CommandText = "SELECT [Level], [Message], [Number], [LogEvent], [Properties], [Exception] FROM [dbo].[$table] ORDER BY [Id]"
            $reader = $command.ExecuteReader()
            $events = @(
                while ($reader.Read()) {
                    $json = $reader.GetString(3) | ConvertFrom-Json
                    $json.Properties.Number | Should -Be 42
                    $properties = [xml]$reader.GetString(4)
                    $properties.SelectSingleNode('/properties/property[@key="Number"]').InnerText | Should -Be '42'
                    if ($reader.GetString(0) -eq 'Error') { $reader.GetString(5) | Should -Match 'integration exception' }
                    [pscustomobject]@{ Level = $reader.GetString(0); Message = $reader.GetString(1); Number = $reader.GetInt32(2) }
                }
            )
            $reader.Dispose()
            Assert-IntegrationEvents $events $id
        } finally { $connection.Dispose() }
    }
    AfterEach {
        Close-Logger
        [Serilog.Debugging.SelfLog]::Disable()
        $safe = $script:diagnostics.ToString().Replace($env:POSHLOG_SQL_CONNECTION_STRING, '[connection]')
        if ($env:MSSQL_SA_PASSWORD) { $safe = $safe.Replace($env:MSSQL_SA_PASSWORD, '[credential]') }
        if ($safe) { Write-Host $safe }
        $script:diagnostics.Dispose()
    }
}
