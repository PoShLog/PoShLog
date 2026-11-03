# Regression coverage for the v2 maintenance release (#46, #45, #28).
BeforeAll {
	$script:manifest = (Resolve-Path "$PSScriptRoot\..\src\PoShLog.psd1").Path
	Import-Module $script:manifest -Force

	function Invoke-ChildPowerShell([string]$Body) {
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
			$output.Result
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

Describe 'Console and transcript (#45, #28)' {
	It 'shows and transcribes the same levels with default preferences (#45)' {
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
			$text | Should -Not -Match $marker
		}
	}

	It 'transcribes all enabled PowerShell streams (#45)' {
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
			[regex]::Matches($text, $marker).Count | Should -Be 1
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
