$ModuleDirectory = "$PSScriptRoot\..\src"

Describe "PoShLog-main" {
	It "imports the module" {
		{
			Import-Module "$ModuleDirectory\PoShLog.psm1" -Force
		} | Should -Not -Throw
	}
	It "imports the module using manifest" {
		{
			Import-Module "$ModuleDirectory\PoShLog.psd1" -Force
		} | Should -Not -Throw
	}
}

Describe "PoShLog-extended" {
	Context "Test all functions for throws" {
		It "should create a new logger without throwing" {
			{ 
				New-Logger |
				Set-MinimumLevel -Value Verbose |
				Add-SinkPowerShell -OutputTemplate '[{Timestamp:HH:mm:ss}] {Message:lj}' |
				Add-SinkFile -Path "$env:TEMP\testlog.log" |
				Start-Logger
			} | Should -Not -Throw
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
			Remove-Item "$env:TEMP\testlog.log"
		}
	}

	Context "Test console output functionality, including correct streams" {
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
		It "should write an information log when InformationPreference is Continue" {
			$global:InformationPreference = 'Continue'
			(Write-InfoLog 'Test Information message') 6>&1 | Should -BeLike "* Test Information message"
		}
		It "should NOT write an information log when InformationPreference is SilentlyContinue" {
			$global:InformationPreference = 'SilentlyContinue'
			# kinda hacky PSScriptRoot, cause InformationPreference still lets itself redirect to success stream even if SilentlyContinue
			(Write-InfoLog 'Test Information message') 6>$null | Should -Be $null
		}
		It "should NOT write a warning log when WarningPreference is SilentlyContinue" {
			$global:WarningPreference = 'SilentlyContinue'
			(Write-WarningLog 'Test warning message') 3>&1 | Should -Be $null
		}
		It "should write a warning log when WarningPreference is Continue" {
			$global:WarningPreference = 'Continue'
			(Write-WarningLog 'Test warning message') 3>&1 | Should -BeLike "* Test warning message"
		}
		It "should write a error log" {
			(Write-ErrorLog 'Test error message') 6>&1 | Should -BeLike "* Test error message"
		}
		It "should write a fatal log" {
			(Write-FatalLog 'Test fatal message') 6>&1 | Should -BeLike "* Test fatal message"
		}
		AfterAll {
			Close-Logger
		}
	}
}

if (Get-Module PoShLog -ErrorAction SilentlyContinue) {
	Remove-Module PoShLog
}