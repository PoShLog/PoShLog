$here = (Split-Path -Parent $MyInvocation.MyCommand.Path)
$beforeChangeLocation = Get-Location

Describe "PoShLog-main" {
    It "loads Module" {
        {
            # set location should not be needed, check PSScriptRoot in .psm1
            Set-Location "$here\..\src\"
            # Import-Module PoShLog --> Doesnt work!!
            Import-Module "$here\..\src\PoShLog.psm1" -Force
        } | Should -Not -Throw
    }
}

# Checks for correct style in the module-functions (commentBasedHelp etc)
Describe "PoShLog-styleChecks" {
    BeforeAll {
        $functions = @( Get-ChildItem -Path $PSScriptRoot\..\src\functions\*.ps1 -Recurse )
    }

    # Get-Content all functions/classes from module and check for commentbased-help
    foreach ($import in $functions) {
        try {
            $content = Get-Content $import.fullname
            It "$($import.name) has comment-based-help" {
                #First line of content starts with "<#"
                $content[1].startsWith("`t<#") | Should -BeTrue
            }
        }
        catch {
            Write-Error -Message "Failed to get content for $($import.fullname): $_"
        }
    }
}


Describe "PoShLog-extended" {
    Context "Test all functions for errors" {
        It "should create a new logger without errors" {
            { 
                New-Logger |
                Set-MinimumLevel -Value Verbose |
                Add-SinkPowerShell -OutputTemplate '[{Timestamp:HH:mm:ss}] {Message:lj}' |
                Add-SinkFile -Path "$here\testlog.log" |
                Start-Logger
            }  | Should -Not -Throw
        }
        It "should write a verbose log without throwing" {
            { Write-VerboseLog 'Test verbose message' } | Should -Not -Throw
        }
        It "should write a debug log without throwing" {
            { Write-DebugLog 'Test Debug message' } | Should -Not -Throw
        }
        It "should write a info log without throwing" {
            { Write-InfoLog 'Test info message' } | Should -Not -Throw
        }
        It "should write a warning log without throwing" {
            { Write-WarningLog 'Test warning message' } | Should -Not -Throw
        }
        It "should write a error log without throwing" {
            { Write-ErrorLog 'Test error message' } | Should -Not -Throw
        }
        It "should write a fatal log without throwing" {
            { Write-FatalLog 'Test fatal message' } | Should -Not -Throw
        }
        It "should display formatted output without throwing" {
            {
                $position = @{
                    Latitude  = 25
                    Longitude = 134
                }
                $elapsedMs = 34
                Write-InfoLog 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs
            } | Should -Not -Throw
        }
        
        It "should close logger without throwing" {
            { Close-Logger } | Should -Not -Throw
        }
        AfterAll {
            Remove-Item "$here\testlog.log"
        }
    }

    Context "Test console output functionality" {
        BeforeAll { 
            New-Logger |
            Set-MinimumLevel -Value Verbose |
            Add-SinkPowerShell -OutputTemplate '[{Timestamp:HH:mm:ss}] {Message:lj}' |
            Start-Logger
        }
        It "should write a verbose log when VerbosePreference is Continue" {
            $global:VerbosePreference = 'Continue'
            (Write-VerboseLog 'Test verbose message') 4>&1 | Should -BeLike "* Test verbose message"
        }
        It "should NOT write a verbose log when VerbosePreference is SilentlyContinue" {
            $global:VerbosePreference = 'SilentlyContinue'
            (Write-VerboseLog 'Test verbose message') 4>&1 | Should -Be $null
        }
        It "should write a debug log when DebugPreference is Continue" {
            $global:DebugPreference = 'Continue'
            (Write-DebugLog 'Test Debug message') 5>&1 | Should -BeLike "* Test Debug message"
        }
        It "should NOT write a debug log when DebugPreference is SilentlyContinue" {
            $global:DebugPreference = 'SilentlyContinue'
            (Write-DebugLog 'Test Debug message') 5>&1 | Should -Be $null
        }
        It "should write a info log" {
            Write-InfoLog 'Test info message'
        }
        It "should write a warning log" {
            Write-WarningLog 'Test warning message'
        }
        It "should write a error log" {
            Write-ErrorLog 'Test error message'
        }
        It "should write a fatal log" {
            Write-FatalLog 'Test fatal message'
        }
        AfterAll {
            Close-Logger
        }
    }
}

Remove-Module PoShLog
Set-Location $beforeChangeLocation