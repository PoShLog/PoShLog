# Recipe: testing code that logs, with Pester

Two ways to test a function that logs through PoShLog:

- **Mock the logging commands.** Fast, needs no logger, and checks which template and values the code passes.
- **Capture the real events.** Starts a logger that writes compact JSON to a file in `TestDrive`, then reads the
  events back with their level and properties.

Samples in [samples/pester/](../../samples/pester/): [Backup.ps1](../../samples/pester/Backup.ps1) is the code under
test, [Backup.Tests.ps1](../../samples/pester/Backup.Tests.ps1) holds both kinds of test. Pester 5.5 or newer.

## The code under test

```powershell
function Invoke-Backup {
    param([string]$Source, [string]$Destination)

    if (!(Test-Path -LiteralPath $Source -PathType Container)) {
        Write-ErrorLog 'Backup source {Source} does not exist' -PropertyValues $Source
        throw "Backup source '$Source' does not exist."
    }
    # ... copy, Write-DebugLog 'Copied {File}' per file ...
    Write-InfoLog 'Copied {FileCount} files from {Source} to {Destination}' -PropertyValues $files.Count, $Source, $Destination
}
```

## Import PoShLog first

```powershell
BeforeAll {
    Import-Module PoShLog -MinimumVersion 3.0.0
    . $PSScriptRoot/Backup.ps1
}
```

Import the module in `BeforeAll`, before any setup that uses it. `Mock` needs the commands to exist, and type names
such as `[Serilog.Events.LogEventLevel]` are known only after the module has loaded its assemblies.

## Mock the logging commands

```powershell
Describe 'Invoke-Backup with mocked logging' {
    BeforeAll {
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
}
```

The parameter filter sees the command's parameters: `$MessageTemplate`, `$PropertyValues`, `$Exception` and
`$ErrorRecord`. Compare the template, not the rendered text, so that a test does not depend on formatting.

## Capture the real events

```powershell
Describe 'Invoke-Backup with captured events' {
    BeforeAll {
        function Get-LoggedEvent {
            # Close-Logger flushes the file before it is read.
            Close-Logger
            Get-Content -LiteralPath $events | ConvertFrom-Json
        }
    }

    BeforeEach {
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
        Invoke-Backup -Source $source -Destination $destination

        $summary = Get-LoggedEvent | Where-Object '@mt' -eq 'Copied {FileCount} files from {Source} to {Destination}'
        $summary.FileCount | Should -Be 2
        $summary.Source | Should -Be $source
        # CLEF leaves the level out for Information.
        $summary.'@l' | Should -BeNullOrEmpty
    }

    It 'writes one Debug event per file' {
        Invoke-Backup -Source $source -Destination (Join-Path $TestDrive 'debug')

        $copied = @(Get-LoggedEvent | Where-Object '@l' -eq 'Debug')
        $copied.File | Sort-Object | Should -Be 'a.txt', 'b.txt'
    }
}
```

- Each test gets its own file and its own logger, so events from one test never show up in another.
- `Get-CompactFormatter` without `-Rendered` writes the template in `@mt`, which is the stable thing to match on.
  Properties are top-level fields of each event, with their types: `FileCount` is a number, not a string.
- `AfterEach` closes the logger also when a test fails before it reads the events.

## Expected output

```text
Describing Invoke-Backup with mocked logging
  [+] logs the number of copied files
  [+] logs an error before it throws
Describing Invoke-Backup with captured events
  [+] writes the file count and the paths as properties
  [+] writes one Debug event per file
  [+] writes an Error event for a missing source
Tests Passed: 5, Failed: 0, Skipped: 0
```

## Missing events?

- **The mock is never invoked, but the log shows the event.** The code under test lives in a module. Mock the command
  in the module's scope: `Mock Write-InfoLog -ModuleName MyModule`, and the same `-ModuleName` on `Should -Invoke`.
- **`Unable to find type [Serilog.Events.LogEventLevel]`.** PoShLog was not imported yet when that line ran. Import it
  in the top-level `BeforeAll`, before the setup that uses the type; or pass the level by name,
  `Set-MinimumLevel -Value Debug`.
- **The event file is empty or misses the last events.** Read it only after `Close-Logger`, which flushes it.
- **Debug events are missing.** The default minimum level is Information; set it to Debug in the test logger.
- **Events from another test show up.** A logger from an earlier test is still open. Close it in `AfterEach`, and give
  each test its own file.
- **The code under test starts its own logger.** Then it replaces the test logger. Move logger setup out of the
  function into the script's entry point, or mock `Start-Logger` and assert on the logging commands instead.

## Verified

`build/Test-Recipes.ps1` runs `Backup.Tests.ps1` in a new `pwsh` process against the staged package and checks that all
five tests pass and that the staged PoShLog was the one loaded.
