#Requires -Version 7.6
# Runs every recipe sample in a new pwsh process against the staged PoShLog package. Start it with
# build/Test-Recipes.ps1, which stages the package and sets POSHLOG_RECIPES_MODULES.

BeforeAll {
	$script:modules = $env:POSHLOG_RECIPES_MODULES
	if (!$modules -or !(Test-Path (Join-Path $modules 'PoShLog/PoShLog.psd1'))) {
		throw 'POSHLOG_RECIPES_MODULES must name a folder with the staged PoShLog module. Run build/Test-Recipes.ps1.'
	}
	$script:pwsh = Join-Path $PSHOME 'pwsh'

	# Runs a sample like a scheduler or a CI runner would: a new process, no profile, the staged module first on the path.
	function Invoke-Sample {
		param([string[]]$Arguments, [hashtable]$Environment = @{}, [string]$WorkingDirectory = $TestDrive)
		$saved = @{}
		$Environment['PSModulePath'] = $modules + [IO.Path]::PathSeparator + $env:PSModulePath
		foreach ($name in $Environment.Keys) {
			$saved[$name] = [Environment]::GetEnvironmentVariable($name)
			[Environment]::SetEnvironmentVariable($name, $Environment[$name])
		}
		Push-Location $WorkingDirectory
		try {
			$output = & $pwsh -NoProfile -NonInteractive @Arguments 2>&1 | ForEach-Object { "$_" }
			[pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output -join "`n" }
		}
		finally {
			Pop-Location
			foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
		}
	}
}

Describe 'The staged package' {
	It 'is the PoShLog the samples import' {
		$result = Invoke-Sample -Arguments '-Command', 'Import-Module PoShLog; (Get-Module PoShLog).ModuleBase'

		$result.Output | Should -Be (Resolve-Path (Join-Path $modules 'PoShLog')).Path
	}
}

Describe 'Recipe: scheduled script' {
	BeforeAll {
		$script:sample = Join-Path $PSScriptRoot 'scheduled-script/Invoke-NightlyCleanup.ps1'
	}

	BeforeEach {
		$script:exports = Join-Path $TestDrive "exports-$([guid]::NewGuid().ToString('N'))"
		$script:logs = Join-Path $exports 'logs'
		New-Item -ItemType Directory $exports | Out-Null
		$old = New-Item (Join-Path $exports 'old.csv') -Value 'old'
		$old.LastWriteTime = (Get-Date).AddDays(-40)
		New-Item (Join-Path $exports 'new.csv') -Value 'new' | Out-Null
	}

	It 'removes the old files, logs to the console and the daily file, and exits with 0' {
		$result = Invoke-Sample -Arguments '-File', $sample, '-Path', $exports, '-OlderThanDays', '30', '-LogDirectory', $logs

		$result.ExitCode | Should -Be 0
		Join-Path $exports 'old.csv' | Should -Not -Exist
		Join-Path $exports 'new.csv' | Should -Exist
		$result.Output | Should -Match '\[\d\d:\d\d:\d\d INF\] Removed 1 files \(3 bytes\)'
		$file = Join-Path $logs "nightly-cleanup-$(Get-Date -Format yyyyMMdd).log"
		$file | Should -Exist
		$text = Get-Content -LiteralPath $file -Raw
		$text | Should -Match '\[INF\] Removing files older than 30 days from .+exports-\w+ \{"Job":"nightly-cleanup"\}'
		$text | Should -Match '\[INF\] Removed 1 files \(3 bytes\) \{"Job":"nightly-cleanup"\}'
	}

	It 'logs the failure, flushes the file and exits with 1' {
		$missing = Join-Path $exports 'missing'
		$result = Invoke-Sample -Arguments '-File', $sample, '-Path', $missing, '-LogDirectory', $logs

		$result.ExitCode | Should -Be 1
		$text = Get-Content -LiteralPath (Join-Path $logs "nightly-cleanup-$(Get-Date -Format yyyyMMdd).log") -Raw
		$text | Should -Match '\[FTL\] Cleanup of .+missing failed'
		$text | Should -Match 'ItemNotFoundException'
	}
}

Describe 'Recipe: GitHub Actions' {
	BeforeAll {
		$script:check = Join-Path $PSScriptRoot 'github-actions/Test-JsonFiles.ps1'
		$script:annotate = Join-Path $PSScriptRoot 'github-actions/Write-LogAnnotations.ps1'
		$script:actions = @{ GITHUB_WORKFLOW = 'Check JSON'; GITHUB_RUN_ID = '4242' }
	}

	BeforeEach {
		$script:config = Join-Path $TestDrive "config-$([guid]::NewGuid().ToString('N'))"
		New-Item -ItemType Directory (Join-Path $config 'nested') -Force | Out-Null
		Set-Content (Join-Path $config 'app.json') '{ "name": "app" }'
		Set-Content (Join-Path $config 'nested/feature.json') '[1, 2]'
		Set-Content (Join-Path $config 'empty.json') ''
		$script:log = Join-Path $config 'out/test-json.clef'
	}

	It 'writes readable lines to the job log and every event to the CLEF file, and exits with 0' {
		$result = Invoke-Sample -Arguments '-File', $check, '-Path', $config, '-LogPath', $log -Environment $actions.Clone()

		$result.ExitCode | Should -Be 0
		$result.Output | Should -Match '(?m)^\[WRN\] empty.json is empty$'
		$result.Output | Should -Match '(?m)^\[INF\] No invalid JSON in 3 files$'
		$result.Output | Should -Not -Match 'is valid'
		$events = Get-Content -LiteralPath $log | ConvertFrom-Json
		$events.Count | Should -Be 5
		($events | Where-Object '@l' -eq 'Debug').File | Sort-Object | Should -Be 'app.json', ([IO.Path]::Combine('nested', 'feature.json'))
		$events | ForEach-Object { $_.Workflow | Should -Be 'Check JSON'; $_.RunId | Should -Be '4242'; $_.'@m' | Should -Not -BeNullOrEmpty }
	}

	It 'exits with 1 when a file is not valid JSON' {
		Set-Content (Join-Path $config 'broken.json') '{ "name": '
		$result = Invoke-Sample -Arguments '-File', $check, '-Path', $config, '-LogPath', $log -Environment $actions.Clone()

		$result.ExitCode | Should -Be 1
		$result.Output | Should -Match '(?m)^\[ERR\] broken.json is not valid JSON: '
		$result.Output | Should -Match '(?m)^\[ERR\] 1 of 4 files are not valid JSON$'
	}

	It 'turns warnings and errors into annotations and writes the job summary' {
		Set-Content (Join-Path $config 'broken.json') '{ "name": '
		Invoke-Sample -Arguments '-File', $check, '-Path', $config, '-LogPath', $log -Environment $actions.Clone() | Out-Null
		$summary = Join-Path $config 'summary.md'

		$result = Invoke-Sample -Arguments '-File', $annotate, '-Path', $log -Environment @{ GITHUB_STEP_SUMMARY = $summary }

		$result.ExitCode | Should -Be 0
		$lines = $result.Output -split "`n"
		$lines | Should -Contain '::warning title=PoShLog Warning::"empty.json" is empty'
		($lines -like '::error title=PoShLog Error::"broken.json" is not valid JSON: *').Count | Should -Be 1
		$lines | Should -Contain '::error title=PoShLog Error::1 of 4 files are not valid JSON'
		$lines | ForEach-Object { $_ | Should -Match '^::(warning|error) title=PoShLog \w+::[^\r\n]*$' }
		$text = Get-Content -LiteralPath $summary -Raw
		$text | Should -Match '\| Debug \| 2 \|'
		$text | Should -Match '\| Information \| 1 \|'
		$text | Should -Match '\| Warning \| 1 \|'
		$text | Should -Match '\| Error \| 2 \|'
	}

	It 'escapes line breaks and percent signs in annotations' {
		$clef = Join-Path $config 'crafted.clef'
		Set-Content $clef '{"@t":"2026-11-03T10:00:00Z","@m":"50% done\r\nnext","@l":"Fatal","@x":"System.Exception: boom"}'

		$result = Invoke-Sample -Arguments '-File', $annotate, '-Path', $clef

		$result.Output | Should -Be '::error title=PoShLog Fatal::50%25 done%0D%0Anext%0ASystem.Exception: boom'
	}

	It 'warns instead of failing when the log file is missing' {
		$result = Invoke-Sample -Arguments '-File', $annotate, '-Path', (Join-Path $config 'none.clef')

		$result.ExitCode | Should -Be 0
		$result.Output | Should -BeLike '::warning::No log file at *'
	}
}

Describe 'Recipe: Pester' {
	It 'passes with the staged package' {
		$command = @"
Import-Module Pester -MinimumVersion 5.5.0
`$result = Invoke-Pester -Path '$(Join-Path $PSScriptRoot 'pester')' -PassThru -Output None
"Passed=`$(`$result.PassedCount) Failed=`$(`$result.FailedCount) Base=`$((Get-Module PoShLog).ModuleBase)"
"@
		$result = Invoke-Sample -Arguments '-Command', $command

		$result.Output | Should -Match 'Passed=5 Failed=0'
		$result.Output | Should -Match ([regex]::Escape("Base=$((Resolve-Path (Join-Path $modules 'PoShLog')).Path)"))
	}
}
