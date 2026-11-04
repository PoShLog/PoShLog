#Requires -Version 7.4
BeforeAll {
    $root = (Resolve-Path "$PSScriptRoot/..").Path
    $module = "$root/extensions/PoShLog.Sinks.MSSqlServer/PoShLog.Sinks.MSSqlServer.psd1"
    if (!(Test-Path "$root/extensions/PoShLog.Sinks.MSSqlServer/lib/PoShLog.Sinks.MSSqlServer.dll")) {
        & "$root/build/Build-Extension.ps1" -Module PoShLog.Sinks.MSSqlServer | Out-Null
    }
    Import-Module "$root/src/PoShLog.psd1" -Force
    Import-Module $module -Force
    $connection = 'Server=127.0.0.1,1;Database=master;Integrated Security=true;Connect Timeout=1'
}

Describe 'Add-SinkMSSqlServer public contract' {
    It 'exports only the binary sink command' {
        @(Get-Command -Module PoShLog.Sinks.MSSqlServer).Name | Should -Be 'Add-SinkMSSqlServer'
        (Get-Command Add-SinkMSSqlServer).CommandType | Should -Be 'Cmdlet'
    }

    It 'preserves independent pipeline inputs with data-only column options' {
        $first = New-Logger
        $second = New-Logger
        $columns = @{
            Store = @('Id', 'Message', 'Level', 'LogEvent')
            AdditionalColumns = @(@{ ColumnName = 'Number'; DataType = 'Int' })
            LogEvent = @{ ExcludeStandardColumns = $true }
        }
        $output = @(@($first, $second) | Add-SinkMSSqlServer -cnn $connection -TableName Events -SchemaName dbo `
            -BatchPostingLimit 2 -BatchPeriod ([timespan]::FromMilliseconds(100)) -ColumnOptions $columns `
            -RestrictedToMinimumLevel Warning -Formatter (Get-JsonFormatter))
        $output.Count | Should -Be 2
        [object]::ReferenceEquals($first, $output[0]) | Should -BeTrue
        [object]::ReferenceEquals($second, $output[1]) | Should -BeTrue
        foreach ($configuration in $output) { $configuration.CreateLogger().Dispose() }
    }

    It 'rejects a nonpositive batch period' {
        { New-Logger | Add-SinkMSSqlServer -ConnectionString $connection -BatchPeriod ([timespan]::Zero) } |
            Should -Throw '*BatchPeriod must be positive*'
    }

    It 'rejects a nonpositive batch limit' {
        { New-Logger | Add-SinkMSSqlServer -ConnectionString $connection -BatchPostingLimit 0 } | Should -Throw
    }

    It 'reports unknown column options before emitting events' {
        { New-Logger | Add-SinkMSSqlServer -ConnectionString $connection -ColumnOptions @{ Typo = $true } } |
            Should -Throw '*Unknown column option: Typo*'
    }

    It 'reimports without creating another context or exposing SqlClient in the default context' {
        Import-Module $module -Force
        $configuration = New-Logger | Add-SinkMSSqlServer -ConnectionString $connection
        $configuration.CreateLogger().Dispose()
        $contexts = @([Runtime.Loader.AssemblyLoadContext]::All | Where-Object Name -eq 'PoShLog.Sinks.MSSqlServer')
        $contexts.Count | Should -Be 1
        @([Runtime.Loader.AssemblyLoadContext]::Default.Assemblies | Where-Object { $_.GetName().Name -eq 'Microsoft.Data.SqlClient' }).Count |
            Should -Be 0
    }
}
