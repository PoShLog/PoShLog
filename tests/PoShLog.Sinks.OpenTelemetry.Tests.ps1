#Requires -Version 7.4
# PoShLog.Sinks.OpenTelemetry end to end: the module as shipped (psd1, psm1, lib) against a loopback OTLP/HTTP receiver.

BeforeAll {
	$root = (Resolve-Path "$PSScriptRoot\..").Path
	$module = Join-Path $root 'extensions/PoShLog.Sinks.OpenTelemetry'
	if (!(Test-Path (Join-Path $module 'lib/PoShLog.Sinks.OpenTelemetry.dll'))) {
		& (Join-Path $root 'build/Build-Extension.ps1') -Module PoShLog.Sinks.OpenTelemetry | Out-Null
	}
	Import-Module (Join-Path $root 'src/PoShLog.psd1') -Force
	Import-Module (Join-Path $module 'PoShLog.Sinks.OpenTelemetry.psd1') -Force
	if (!('CompatHttpListener' -as [type])) { Add-Type -Path (Join-Path $root 'tests/compat/CompatHttpListener.cs') }

	function Wait-Export($Listener, [string]$Marker) {
		$deadline = [datetime]::UtcNow.AddSeconds(20)
		do {
			$body = $Listener.Bodies.ToArray() -join "`n"
			if ($body.Contains($Marker)) { return $body }
			Start-Sleep -Milliseconds 100
		} while ([datetime]::UtcNow -lt $deadline)
		throw "No OTLP export with $Marker arrived."
	}
}

# Later test files remove PoShLog, which a loaded extension that requires it would block.
AfterAll { Remove-Module PoShLog.Sinks.OpenTelemetry -ErrorAction SilentlyContinue }

Describe 'Add-SinkOpenTelemetry' {
	BeforeEach {
		$script:listener = [CompatHttpListener]::new()
		$script:marker = "otlp-pester-$([guid]::NewGuid().ToString('N'))"
		$script:saved = @{}
		foreach ($name in 'OTEL_EXPORTER_OTLP_ENDPOINT', 'OTEL_SERVICE_NAME') {
			$script:saved[$name] = [Environment]::GetEnvironmentVariable($name)
		}
	}
	AfterEach {
		Close-Logger
		$script:listener.Dispose()
		foreach ($name in $script:saved.Keys) { [Environment]::SetEnvironmentVariable($name, $script:saved[$name]) }
	}

	It 'exports only Add-SinkOpenTelemetry' {
		(Get-Command -Module PoShLog.Sinks.OpenTelemetry).Name | Should -Be 'Add-SinkOpenTelemetry'
	}

	It 'delivers an event to the /v1/logs path of the endpoint' {
		New-Logger | Add-SinkOpenTelemetry -Endpoint $listener.Url -Protocol HttpProtobuf -IgnoreEnvironment `
			-Period ([timespan]::FromMilliseconds(100)) | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Export $listener $marker | Should -Not -BeNullOrEmpty
		$listener.Paths.ToArray() | Should -Contain '/v1/logs'
	}

	It 'lets parameters win over OTEL_* variables' {
		$env:OTEL_EXPORTER_OTLP_ENDPOINT = 'http://127.0.0.1:9'
		$env:OTEL_SERVICE_NAME = 'from-environment'

		New-Logger | Add-SinkOpenTelemetry -Endpoint $listener.Url -ServiceName 'from-parameter' `
			-Period ([timespan]::FromMilliseconds(100)) | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		$body = Wait-Export $listener $marker
		$body | Should -Match 'from-parameter'
		$body | Should -Not -Match 'from-environment'
	}

	It 'imports again into a session that already loaded its assemblies' {
		# The second import finds Protobuf, gRPC and the sink already loaded and must reuse them (ADR 0012).
		{ Import-Module (Join-Path $root 'extensions/PoShLog.Sinks.OpenTelemetry/PoShLog.Sinks.OpenTelemetry.psd1') -Force } |
			Should -Not -Throw
		New-Logger | Add-SinkOpenTelemetry -Endpoint $listener.Url -IgnoreEnvironment -Period ([timespan]::FromMilliseconds(100)) |
			Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Export $listener $marker | Should -Not -BeNullOrEmpty
	}

	It 'uses OTEL_EXPORTER_OTLP_ENDPOINT when no endpoint is given' {
		$env:OTEL_EXPORTER_OTLP_ENDPOINT = $listener.Url

		New-Logger | Add-SinkOpenTelemetry -Period ([timespan]::FromMilliseconds(100)) | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Export $listener $marker | Should -Not -BeNullOrEmpty
	}
}
