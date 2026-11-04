#Requires -Version 7.6
# PoShLog.Sinks.Splunk.Hec end to end: the module as shipped (psd1, psm1, lib) against a loopback HEC stand-in.

BeforeAll {
	$root = (Resolve-Path "$PSScriptRoot\..").Path
	$module = Join-Path $root 'extensions/PoShLog.Sinks.Splunk.Hec'
	if (!(Test-Path (Join-Path $module 'lib/PoShLog.Sinks.Splunk.Hec.dll'))) {
		& (Join-Path $root 'build/Build-Extension.ps1') -Module PoShLog.Sinks.Splunk.Hec | Out-Null
	}
	Import-Module (Join-Path $root 'src/PoShLog.psd1') -Force
	Import-Module (Join-Path $module 'PoShLog.Sinks.Splunk.Hec.psd1') -Force
	if (!('CompatHttpListener' -as [type])) { Add-Type -Path (Join-Path $root 'tests/compat/CompatHttpListener.cs') }

	function Wait-Request($Listener, [string]$Marker) {
		$deadline = [datetime]::UtcNow.AddSeconds(20)
		do {
			$body = $Listener.Bodies.ToArray() -join "`n"
			if ($body.Contains($Marker)) { return $body }
			Start-Sleep -Milliseconds 100
		} while ([datetime]::UtcNow -lt $deadline)
		throw "No HEC request with $Marker arrived."
	}
}

# Later test files remove PoShLog, which a loaded extension that requires it would block.
AfterAll { Remove-Module PoShLog.Sinks.Splunk.Hec -ErrorAction SilentlyContinue }

Describe 'Add-SinkSplunk' {
	BeforeEach {
		$script:listener = [CompatHttpListener]::new()
		$script:marker = "hec-pester-$([guid]::NewGuid().ToString('N'))"
	}
	AfterEach {
		Close-Logger
		$script:listener.Dispose()
	}

	It 'exports only Add-SinkSplunk' {
		(Get-Command -Module PoShLog.Sinks.Splunk.Hec).Name | Should -Be 'Add-SinkSplunk'
	}

	It 'delivers a Splunk JSON event to services/collector/event' {
		New-Logger | Add-SinkSplunk -Url $listener.Url -Token 'placeholder' -Index 'main' -BatchInterval 0.1 | Start-Logger
		Write-InfoLog "$marker {User}" -PropertyValues 'tomas'
		Close-Logger

		$event = (Wait-Request $listener $marker) -split "`n" | Where-Object { $_ -like "*$marker*" } | ConvertFrom-Json
		$event.index | Should -Be 'main'
		$event.event.Properties.User | Should -Be 'tomas'
		$listener.Paths.ToArray() | Should -Contain '/services/collector/event'
	}

	It 'delivers a text line to services/collector/raw with metadata in the query' {
		New-Logger | Add-SinkSplunk -Url $listener.Url -Token 'placeholder' -Endpoint Raw -SourceType 'poshlog' `
			-OutputTemplate '{Message:lj}' -BatchInterval 0.1 | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Request $listener $marker | Should -Be $marker
		$listener.Paths.ToArray() | Should -Contain '/services/collector/raw?sourcetype=poshlog'
	}

	It 'imports again into a session that already loaded its assemblies' {
		{ Import-Module (Join-Path $root 'extensions/PoShLog.Sinks.Splunk.Hec/PoShLog.Sinks.Splunk.Hec.psd1') -Force } |
			Should -Not -Throw
		New-Logger | Add-SinkSplunk -Url $listener.Url -Token 'placeholder' -BatchInterval 0.1 | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Request $listener $marker | Should -Not -BeNullOrEmpty
	}

	It 'refuses to import next to an older Serilog.Sinks.Splunk' {
		# Stands in for the third-party PoShLog.Sinks.Splunk 1.0.4, which ships Serilog.Sinks.Splunk 3.7.0. A child process
		# keeps the fake assembly out of this session.
		$child = @"
`$name = [Reflection.AssemblyName]::new('Serilog.Sinks.Splunk')
`$name.Version = [version]'3.7.0.0'
`$null = [Reflection.Emit.AssemblyBuilder]::DefineDynamicAssembly(`$name, 'Run')
Import-Module '$root/src/PoShLog.psd1'
try { Import-Module '$root/extensions/PoShLog.Sinks.Splunk.Hec/PoShLog.Sinks.Splunk.Hec.psd1' -ErrorAction Stop; 'IMPORTED' }
catch { `$_.Exception.Message }
"@
		$output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $child

		$output | Should -Match 'needs Serilog\.Sinks\.Splunk .*but 3\.7\.0\.0 is already loaded'
	}
}
