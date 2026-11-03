# Regression coverage for the v2 maintenance release.
BeforeAll {
	$script:manifest = (Resolve-Path "$PSScriptRoot\..\src\PoShLog.psd1").Path
	Import-Module $script:manifest -Force

	function Invoke-ChildPowerShell([string]$Body, [switch]$IncludeErrors) {
		$path = Join-Path $TestDrive "$([guid]::NewGuid()).ps1"
		Set-Content -LiteralPath $path -Value ("`$ErrorActionPreference = 'Stop'`nImport-Module '$($script:manifest.Replace("'", "''"))'`n" + $Body)
		$exe = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh.exe' }
		$start = New-Object System.Diagnostics.ProcessStartInfo
		$start.FileName = Join-Path $PSHOME $exe
		$start.Arguments = '-NoProfile -NonInteractive -File "' + $path + '"'
		$start.UseShellExecute = $false
		$start.CreateNoWindow = $true
		$start.RedirectStandardOutput = $true
		$start.RedirectStandardError = $true
		$process = [System.Diagnostics.Process]::Start($start)
		try {
			$output = $process.StandardOutput.ReadToEndAsync()
			$errors = $process.StandardError.ReadToEndAsync()
			if (-not $process.WaitForExit(30000)) {
				$process.Kill()
				throw 'Child PowerShell timed out.'
			}
			if ($process.ExitCode -ne 0) { throw $errors.Result }
			if ($IncludeErrors) { [pscustomobject]@{ Output = $output.Result; Errors = $errors.Result } }
			else { $output.Result }
		} finally { $process.Dispose() }
	}
}

Describe 'Select-Object property values (#46)' {
	AfterEach { Close-Logger }

	It 'logs calculated properties as scalar values, including PassThru' {
		$log = Join-Path $TestDrive 'selected.log'
		New-Logger | Add-SinkFile -Path $log -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger
		$service = [pscustomobject]@{ Name = 'EventLog'; Status = 'Running' } |
			Select-Object Name, Status, @{ l = 'canControl'; e = { 'canControl' } }
		$values = [object[]]@($service.Name, $service.Status, $service.canControl, 'off')
		$rendered = Write-InfoLog 'Service {@Name} is {@Status} and {@Control} because {Reason}.' -PropertyValues $values -PassThru
		Close-Logger
		$expected = 'Service EventLog is Running and canControl because off.'
		# Compare lengths first to avoid dumping the old recursive output on failure.
		$rendered.Length | Should -Be $expected.Length
		$rendered | Should -Be $expected
		(Get-Content $log -Raw) | Should -Be ($expected + [Environment]::NewLine)
		$values[2] | Should -Be 'canControl'
	}

	It 'preserves nulls, arrays, numeric formatting and non-destructured strings' {
		New-Logger | Start-Logger
		$item = 1 | Select-Object @{ n = 'Number'; e = { 7 } }, @{ n = 'Text'; e = { 'hello' } }
		Write-InfoLog '{Number:000} {Text} {Nothing} {@Items}' -PropertyValues $item.Number, $item.Text, $null, ([int[]]@(1, 2)) -PassThru |
			Should -Be '007 hello null [1,2]'
	}
}

Describe 'Information stream compatibility' {
	It 'captures an information record with 6>&1 in a fresh session' {
		$result = Invoke-ChildPowerShell @'
if ($InformationPreference -ne 'SilentlyContinue') { throw 'Unexpected default InformationPreference.' }
New-Logger | Add-SinkPowerShell | Start-Logger
try {
    $records = @(& { Write-InfoLog 'hello {N}' -PropertyValues 1 } 6>&1)
    [pscustomobject]@{
        Count = $records.Count
        IsInformationRecord = $records.Count -eq 1 -and $records[0] -is [System.Management.Automation.InformationRecord]
        Message = ($records | ForEach-Object { $_.ToString() }) -join ''
    } | ConvertTo-Json -Compress
} finally { Close-Logger }
'@
		$captured = $result | ConvertFrom-Json
		$captured.Count | Should -Be 1
		$captured.IsInformationRecord | Should -BeTrue
		$captured.Message | Should -Be 'hello 1'
	}

	It 'captures an information message with 6> file in a fresh session' {
		$path = Join-Path $TestDrive 'information.txt'
		$null = Invoke-ChildPowerShell @"
if (`$InformationPreference -ne 'SilentlyContinue') { throw 'Unexpected default InformationPreference.' }
New-Logger | Add-SinkPowerShell | Start-Logger
try { & { Write-InfoLog 'hello {N}' -PropertyValues 1 } 6> '$path' }
finally { Close-Logger }
"@
		@(Get-Content -LiteralPath $path).Count | Should -Be 1
		(Get-Content -LiteralPath $path -Raw).Trim() | Should -Be 'hello 1'
	}
}

Describe 'Console and transcript (#45, #28)' {
	It 'writes structured JSON with a console formatter (#31, #40, discussion #38)' {
		$console = Invoke-ChildPowerShell @'
New-Logger | Add-SinkConsole -Formatter (Get-JsonFormatter) -RestrictedToMinimumLevel Warning | Start-Logger
try {
    Write-InfoLog 'hidden-marker'
    Write-WarningLog 'Hello {Name}' -PropertyValues 'world'
} finally { Close-Logger }
'@
		$event = $console | ConvertFrom-Json
		$event.Level | Should -Be 'Warning'
		$event.MessageTemplate | Should -Be 'Hello {Name}'
		$event.Properties.Name | Should -Be 'world'
		$console | Should -Not -Match 'hidden-marker'
	}

	It 'keeps the console text and theme parameter set' {
		$console = Invoke-ChildPowerShell @'
New-Logger | Add-SinkConsole -OutputTemplate 'text:{Message:lj}{NewLine}' -Theme ([Serilog.Sinks.SystemConsole.Themes.ConsoleTheme]::None) | Start-Logger
try { Write-WarningLog 'text-marker' } finally { Close-Logger }
'@
		$console.Trim() | Should -Be 'text:text-marker'
	}

	It 'honors the level switch and standard error threshold with a formatter' {
		$result = Invoke-ChildPowerShell -IncludeErrors -Body @'
$switch = New-Object Serilog.Core.LoggingLevelSwitch ([Serilog.Events.LogEventLevel]::Error)
New-Logger | Add-SinkConsole -Formatter (Get-JsonFormatter) -LevelSwitch $switch -StandardErrorFromLevel Error | Start-Logger
try {
    Write-WarningLog 'hidden-marker'
    Write-ErrorLog 'error-marker'
    $switch.MinimumLevel = [Serilog.Events.LogEventLevel]::Warning
    Write-WarningLog 'warning-marker'
} finally { Close-Logger }
'@
		($result.Output | ConvertFrom-Json).MessageTemplate | Should -Be 'warning-marker'
		($result.Errors | ConvertFrom-Json).MessageTemplate | Should -Be 'error-marker'
	}

	It 'rejects text formatting options in the formatter parameter set' {
		{ New-Logger | Add-SinkConsole -Formatter (Get-JsonFormatter) -OutputTemplate '{Message}' } | Should -Throw
	}
	It 'shows and transcribes Warning, Error and Fatal with default preferences (#45)' {
		$transcript = Join-Path $TestDrive 'default.txt'
		$console = Invoke-ChildPowerShell @"
Start-Transcript -Path '$transcript' | Out-Null
try {
    New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger
    Write-VerboseLog 'hidden-verbose-marker'
    Write-DebugLog 'hidden-debug-marker'
    Write-InfoLog 'hidden-info-marker'
    Write-WarningLog 'shown-warning-marker'
    Write-ErrorLog 'shown-error-marker'
    Write-FatalLog 'shown-fatal-marker'
} finally { Close-Logger; Stop-Transcript | Out-Null }
"@
		$text = Get-Content $transcript -Raw
		foreach ($marker in 'shown-warning-marker', 'shown-error-marker', 'shown-fatal-marker') {
			[regex]::Matches($console, $marker).Count | Should -Be 1
			[regex]::Matches($text, $marker).Count | Should -Be 1
		}
		foreach ($marker in 'hidden-verbose-marker', 'hidden-debug-marker', 'hidden-info-marker') {
			$console | Should -Not -Match $marker
			if ($marker -ne 'hidden-info-marker') { $text | Should -Not -Match $marker }
		}
	}

	It 'displays enabled streams and transcribes Verbose, Debug, Warning, Error and Fatal (#45)' {
		$transcript = Join-Path $TestDrive 'enabled.txt'
		$console = Invoke-ChildPowerShell @"
`$VerbosePreference = `$DebugPreference = `$InformationPreference = 'Continue'
Start-Transcript -Path '$transcript' | Out-Null
try {
    New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger
    Write-VerboseLog 'verbose-marker'
    Write-DebugLog 'debug-marker'
    Write-InfoLog 'info-marker'
    Write-WarningLog 'warning-marker'
    Write-ErrorLog 'error-marker'
    Write-FatalLog 'fatal-marker'
} finally { Close-Logger; Stop-Transcript | Out-Null }
"@
		$text = Get-Content $transcript -Raw
		foreach ($marker in 'verbose-marker', 'debug-marker', 'info-marker', 'warning-marker', 'error-marker', 'fatal-marker') {
			[regex]::Matches($console, $marker).Count | Should -Be 1
			# Preserve Write-Information behavior; its transcription depends on the host version.
			if ($marker -ne 'info-marker') { [regex]::Matches($text, $marker).Count | Should -Be 1 }
		}
	}

	It 'prints each event once with Start-Logger -Console (#28)' {
		$console = Invoke-ChildPowerShell @'
Start-Logger -Console
try {
    Write-WarningLog 'once-warning-marker'
    Write-ErrorLog 'once-error-marker'
} finally { Close-Logger }
'@
		[regex]::Matches($console, 'once-warning-marker').Count | Should -Be 1
		[regex]::Matches($console, 'once-error-marker').Count | Should -Be 1
	}

	It 'keeps host records redirectable without changing error control flow (#45)' {
		New-Logger | Add-SinkPowerShell | Start-Logger
		try {
			$ErrorActionPreference = 'Stop'
			$InformationPreference = 'SilentlyContinue'
			$records = @(Write-ErrorLog 'redirect-error-marker' 6>&1)
			$records.Count | Should -Be 1
			$records[0] | Should -BeOfType ([System.Management.Automation.InformationRecord])
			$records[0].Tags | Should -Contain 'PSHOST'
			$records[0].MessageData.ForegroundColor | Should -Be ([ConsoleColor]::Red)
			$records[0].ToString() | Should -Be 'redirect-error-marker'
			$path = Join-Path $TestDrive 'redirect.txt'
			Write-FatalLog 'redirect-fatal-marker' 6> $path
			(Get-Content $path -Raw).Trim() | Should -Be 'redirect-fatal-marker'
			$records = @(Write-InfoLog 'explicit-info-marker' -InformationAction Continue 6>&1)
			$records.Count | Should -Be 1
			$records[0].ToString() | Should -Be 'explicit-info-marker'
			@(Write-InfoLog 'ignored-info-marker' -InformationAction Ignore 6>&1).Count | Should -Be 0
		} finally { Close-Logger }
	}

	It 'keeps the default PowerShell sink and allows explicitly selecting both sinks' {
		$console = Invoke-ChildPowerShell @'
Start-Logger
Write-WarningLog 'default-marker'
Close-Logger
Start-Logger -Console -PowerShell
Write-WarningLog 'both-marker'
Close-Logger
'@
		[regex]::Matches($console, 'default-marker').Count | Should -Be 1
		[regex]::Matches($console, 'both-marker').Count | Should -Be 2
	}
}
