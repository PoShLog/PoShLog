Describe "PoShLog-main" {
	It "imports the module using manifest" {
		{
			Import-Module "$PSScriptRoot\..\src\PoShLog.psd1" -Force
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
				Add-SinkFile -Path (Join-Path ([IO.Path]::GetTempPath()) 'testlog.log') |
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
			Remove-Item (Join-Path ([IO.Path]::GetTempPath()) 'testlog.log')
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

Describe "PoShLog-e2e" {
	BeforeAll {
		Import-Module "$PSScriptRoot\..\src\PoShLog.psd1" -Force
	}

	Context "Full pipeline scenario" {
		It "should build a logger through New-Logger | Set-MinimumLevel | Add-SinkConsole | Start-Logger without throwing" {
			{
				New-Logger |
				Set-MinimumLevel -Value Verbose |
				Add-SinkConsole |
				Start-Logger
			} | Should -Not -Throw
		}
		It "should expose the started logger via Get-Logger" {
			$logger = Get-Logger
			$logger | Should -Not -BeNullOrEmpty
			$logger.GetType().FullName | Should -Be 'Serilog.Core.Logger'
		}
		AfterAll {
			Close-Logger
		}
	}

	Context "Logging at each level" {
		BeforeAll {
			$global:VerbosePreference = 'Continue'
			$global:DebugPreference = 'Continue'
			$global:InformationPreference = 'Continue'
			$global:WarningPreference = 'Continue'

			New-Logger |
			Set-MinimumLevel -Value Verbose |
			Add-SinkPowerShell |
			Start-Logger
		}

		It "should write a message at the <Level> level" -TestCases @(
			@{ Level = 'Verbose'; Cmdlet = 'Write-VerboseLog'; Stream = 4 }
			@{ Level = 'Debug'; Cmdlet = 'Write-DebugLog'; Stream = 5 }
			@{ Level = 'Information'; Cmdlet = 'Write-InformationLog'; Stream = 6 }
			@{ Level = 'Warning'; Cmdlet = 'Write-WarningLog'; Stream = 3 }
			@{ Level = 'Error'; Cmdlet = 'Write-ErrorLog'; Stream = 6 }
			@{ Level = 'Fatal'; Cmdlet = 'Write-FatalLog'; Stream = 6 }
		) {
			param($Level, $Cmdlet, $Stream)

			$message = "Test $Level level message"
			$output = & { & $Cmdlet $message } *>&1
			($output | Out-String) | Should -BeLike "*$message*"
		}

		AfterAll {
			Close-Logger
			$global:VerbosePreference = 'SilentlyContinue'
			$global:DebugPreference = 'SilentlyContinue'
			$global:InformationPreference = 'SilentlyContinue'
			$global:WarningPreference = 'SilentlyContinue'
		}
	}

	Context "File sink writes actual files" {
		BeforeAll {
			$script:logFilePath = (Join-Path ([IO.Path]::GetTempPath()) 'poshlog-e2e-test.log')
			if (Test-Path $script:logFilePath) {
				Remove-Item $script:logFilePath -Force
			}

			New-Logger |
			Set-MinimumLevel -Value Verbose |
			Add-SinkFile -Path $script:logFilePath |
			Start-Logger
		}
		It "should create the log file and write the message content to disk" {
			Write-InfoLog 'Message written to file sink'
			Close-Logger

			$script:logFilePath | Should -Exist
			Get-Content $script:logFilePath -Raw | Should -BeLike '*Message written to file sink*'
		}
		AfterAll {
			if (Test-Path $script:logFilePath) {
				Remove-Item $script:logFilePath -Force
			}
		}
	}

	Context "PowerShell sink routes to correct streams" {
		BeforeAll {
			New-Logger |
			Set-MinimumLevel -Value Verbose |
			Add-SinkPowerShell |
			Start-Logger
		}
		It "should route Information messages to the information stream" {
			$global:InformationPreference = 'Continue'
			(Write-InfoLog 'Routed to information stream') 6>&1 | Should -BeLike '*Routed to information stream'
		}
		It "should route Warning messages to the warning stream" {
			$global:WarningPreference = 'Continue'
			(Write-WarningLog 'Routed to warning stream') 3>&1 | Should -BeLike '*Routed to warning stream'
		}
		It "should route Verbose messages to the verbose stream" {
			$global:VerbosePreference = 'Continue'
			(Write-VerboseLog 'Routed to verbose stream') 4>&1 | Should -BeLike '*Routed to verbose stream'
		}
		AfterAll {
			Close-Logger
			$global:InformationPreference = 'SilentlyContinue'
			$global:WarningPreference = 'SilentlyContinue'
			$global:VerbosePreference = 'SilentlyContinue'
		}
	}

	Context "Close-Logger cleanup" {
		It "should reset the global logger to a non-initialized state" {
			New-Logger | Start-Logger
			Close-Logger

			$logger = Get-Logger
			$logger.GetType().FullName | Should -Not -Be 'Serilog.Core.Logger'
		}
		It "should dispose an explicitly provided logger without throwing" {
			$logger = New-Logger | Start-Logger -PassThru
			{ $logger | Close-Logger } | Should -Not -Throw
		}
		It "should be safe to call multiple times in a row" {
			New-Logger | Start-Logger
			Close-Logger
			{ Close-Logger } | Should -Not -Throw
		}
	}
}

Describe "PoShLog-preview-cmdlets" {
	BeforeAll {
		Import-Module "$PSScriptRoot\..\src\PoShLog.psd1" -Force
	}

	Context "Get-CurrentLogFiles" {
		BeforeAll {
			$script:logFilePath = (Join-Path ([IO.Path]::GetTempPath()) 'poshlog-current-files-test.log')
			if (Test-Path $script:logFilePath) {
				Remove-Item $script:logFilePath -Force
			}

			New-Logger |
			Add-SinkFile -Path $script:logFilePath |
			Start-Logger
		}
		It "should return the active log file path" {
			$files = Get-CurrentLogFiles
			# Compare file names: a Windows runner's TEMP can be an 8.3 short path while Serilog reports the long one.
			$files | ForEach-Object { Split-Path $_ -Leaf } | Should -Contain (Split-Path $script:logFilePath -Leaf)
		}
		AfterAll {
			Close-Logger
			if (Test-Path $script:logFilePath) {
				Remove-Item $script:logFilePath -Force
			}
		}
	}

	Context "Set-DefaultMessageFormatter" {
		BeforeAll {
			New-Logger | Add-SinkConsole | Start-Logger
		}
		It "should change the -PassThru output format" {
			Set-DefaultMessageFormatter -Template '>>{Message:lj}<<'
			$formatted = Write-InfoLog -MessageTemplate 'formatted message' -PassThru
			$formatted | Should -Be '>>formatted message<<'
		}
		AfterAll {
			Close-Logger
		}
	}

	Context "Enable-SelfLog / Disable-SelfLog" {
		It "should invoke a custom self-log callback without throwing" {
			$script:selfLogMessages = [System.Collections.Generic.List[string]]::new()
			$callback = [System.Action[string]] { param($msg) $script:selfLogMessages.Add($msg) }

			{ Enable-SelfLog -MessageFunc $callback } | Should -Not -Throw
			[Serilog.Debugging.SelfLog]::WriteLine('pester self log message')
			($script:selfLogMessages -join [Environment]::NewLine) | Should -BeLike '*pester self log message*'
		}
		It "should disable the self log without throwing" {
			{ Disable-SelfLog } | Should -Not -Throw
		}
	}

	Context "Add-SinkLogger" {
		BeforeAll {
			$script:subLoggerLogFilePath = (Join-Path ([IO.Path]::GetTempPath()) 'poshlog-sub-logger-test.log')
			if (Test-Path $script:subLoggerLogFilePath) {
				Remove-Item $script:subLoggerLogFilePath -Force
			}
		}
		It "should route log events to the sub-logger" {
			$subLogger = New-Logger | Add-SinkFile -Path $script:subLoggerLogFilePath | Start-Logger -PassThru

			New-Logger |
			Add-SinkLogger -Logger $subLogger |
			Start-Logger

			Write-InfoLog 'Routed through Add-SinkLogger'
			Close-Logger
			$subLogger | Close-Logger

			$script:subLoggerLogFilePath | Should -Exist
			Get-Content $script:subLoggerLogFilePath -Raw | Should -BeLike '*Routed through Add-SinkLogger*'
		}
		AfterAll {
			if (Test-Path $script:subLoggerLogFilePath) {
				Remove-Item $script:subLoggerLogFilePath -Force
			}
		}
	}
}

if (Get-Module PoShLog -ErrorAction SilentlyContinue) {
	Remove-Module PoShLog
}