#Requires -Version 7.6
# Pester 5 or newer. Two ways to test code that logs: mock the logging commands, or capture the real events.

BeforeAll {
    # Import PoShLog first, in BeforeAll: Mock needs the commands to exist, and [Serilog.*] type names in the setup
    # below need the module's assemblies loaded.
    Import-Module PoShLog -MinimumVersion 3.0.0
    . $PSScriptRoot/Backup.ps1

    $script:source = Join-Path $TestDrive 'source'
    New-Item -ItemType Directory $source | Out-Null
    'a', 'b' | ForEach-Object { Set-Content -LiteralPath (Join-Path $source "$_.txt") -Value $_ }
}

Describe 'Invoke-Backup with mocked logging' {
    BeforeAll {
        # A mock replaces the command for the code under test; no logger has to be started.
        Mock Write-InfoLog
        Mock Write-DebugLog
        Mock Write-ErrorLog
    }

    It 'logs the number of copied files' {
        Invoke-Backup -Source $source -Destination (Join-Path $TestDrive 'mocked')

        Should -Invoke Write-InfoLog -Times 1 -Exactly -ParameterFilter {
            $MessageTemplate -eq 'Copied {FileCount} files from {Source} to {Destination}' -and $PropertyValues[0] -eq 2
        }
        Should -Invoke Write-DebugLog -Times 2 -Exactly
    }

    It 'logs an error before it throws' {
        { Invoke-Backup -Source (Join-Path $TestDrive 'missing') -Destination $TestDrive } | Should -Throw '*does not exist*'

        Should -Invoke Write-ErrorLog -Times 1 -Exactly -ParameterFilter { $PropertyValues[0] -like '*missing' }
    }
}

Describe 'Invoke-Backup with captured events' {
    BeforeAll {
        function Get-LoggedEvent {
            # Close-Logger flushes the file before it is read.
            Close-Logger
            Get-Content -LiteralPath $events | ConvertFrom-Json
        }
    }

    BeforeEach {
        # A real logger that writes compact JSON (CLEF) to a file in TestDrive: every event with its level and properties.
        $script:events = Join-Path $TestDrive "events-$([guid]::NewGuid().ToString('N')).clef"
        New-Logger |
            Set-MinimumLevel -Value ([Serilog.Events.LogEventLevel]::Debug) |
            Add-SinkFile -Path $events -Formatter (Get-CompactFormatter) |
            Start-Logger
    }

    AfterEach {
        Close-Logger
    }

    It 'writes the file count and the paths as properties' {
        $destination = Join-Path $TestDrive 'captured'
        Invoke-Backup -Source $source -Destination $destination

        $summary = Get-LoggedEvent | Where-Object '@mt' -eq 'Copied {FileCount} files from {Source} to {Destination}'
        $summary.FileCount | Should -Be 2
        $summary.Source | Should -Be $source
        $summary.Destination | Should -Be $destination
        # CLEF leaves the level out for Information.
        $summary.'@l' | Should -BeNullOrEmpty
    }

    It 'writes one Debug event per file' {
        Invoke-Backup -Source $source -Destination (Join-Path $TestDrive 'debug')

        $copied = @(Get-LoggedEvent | Where-Object '@l' -eq 'Debug')
        $copied.File | Sort-Object | Should -Be 'a.txt', 'b.txt'
    }

    It 'writes an Error event for a missing source' {
        { Invoke-Backup -Source (Join-Path $TestDrive 'missing') -Destination $TestDrive } | Should -Throw

        $errorEvent = Get-LoggedEvent | Where-Object '@l' -eq 'Error'
        $errorEvent.Source | Should -BeLike '*missing'
    }
}
