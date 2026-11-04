#Requires -Version 7.6
# PoShLog.Sinks.Elastic end to end: the module as shipped (psd1, psm1, lib) against a loopback Elasticsearch stand-in.

BeforeAll {
	$root = (Resolve-Path "$PSScriptRoot\..").Path
	$module = Join-Path $root 'extensions/PoShLog.Sinks.Elastic'
	if (!(Test-Path (Join-Path $module 'lib/PoShLog.Sinks.Elastic.dll'))) {
		& (Join-Path $root 'build/Build-Extension.ps1') -Module PoShLog.Sinks.Elastic | Out-Null
	}
	Import-Module (Join-Path $root 'src/PoShLog.psd1') -Force
	Import-Module (Join-Path $module 'PoShLog.Sinks.Elastic.psd1') -Force
	if (!('CompatHttpListener' -as [type])) { Add-Type -Path (Join-Path $root 'tests/compat/CompatHttpListener.cs') }

	function Wait-Request($Listener, [string]$Marker) {
		$deadline = [datetime]::UtcNow.AddSeconds(20)
		do {
			$body = $Listener.Bodies.ToArray() -join "`n"
			if ($body.Contains($Marker)) { return $body }
			Start-Sleep -Milliseconds 100
		} while ([datetime]::UtcNow -lt $deadline)
		throw "No bulk request with $Marker arrived."
	}
}

# Later test files remove PoShLog, which a loaded extension that requires it would block.
AfterAll { Remove-Module PoShLog.Sinks.Elastic -ErrorAction SilentlyContinue }

Describe 'Add-SinkElasticsearch' {
	BeforeEach {
		$script:listener = [CompatHttpListener]::new()
		$script:marker = "es-pester-$([guid]::NewGuid().ToString('N'))"
	}
	AfterEach {
		Close-Logger
		$script:listener.Dispose()
	}

	It 'exports only Add-SinkElasticsearch' {
		(Get-Command -Module PoShLog.Sinks.Elastic).Name | Should -Be 'Add-SinkElasticsearch'
	}

	It 'delivers an ECS document to the bulk API of the data stream' {
		New-Logger | Add-SinkElasticsearch -Node $listener.Url -ApiKey 'placeholder' -DataStream 'logs-pester-default' | Start-Logger
		Write-InfoLog "$marker {User}" -PropertyValues 'tomas'
		Close-Logger

		$document = (Wait-Request $listener $marker) -split "`n" | Where-Object { $_ -like "*$marker*" } | ConvertFrom-Json -AsHashtable
		$document['log.level'] | Should -Be 'Information'
		$document['labels']['User'] | Should -Be 'tomas'
		$listener.Paths.ToArray() | Should -Contain '/'
		$listener.Paths.ToArray() | Where-Object { $_ -like '/logs-pester-default/_bulk*' } | Should -Not -BeNullOrEmpty
	}

	It 'imports again into a session that already loaded its assemblies' {
		{ Import-Module (Join-Path $root 'extensions/PoShLog.Sinks.Elastic/PoShLog.Sinks.Elastic.psd1') -Force } |
			Should -Not -Throw
		New-Logger | Add-SinkElasticsearch -Node $listener.Url -ApiKey 'placeholder' | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Request $listener $marker | Should -Not -BeNullOrEmpty
	}

	It 'refuses to import next to an older Elastic.Channels' {
		# Elastic.Channels carries assembly version 0.0.0.0 in every release, so the stub differs only in its file version.
		# A child process keeps it out of this session.
		$stub = Join-Path $TestDrive 'stub/Elastic.Channels.dll'
		New-Item -ItemType Directory -Force (Split-Path $stub) | Out-Null
		# Roslyn directly, not Add-Type -OutputAssembly: that picks a random assembly name and writes no file version.
		$source = @'
[assembly: System.Reflection.AssemblyVersion("0.0.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("0.13.0.0")]
namespace Elastic.Channels { public static class Stub { } }
'@
		$compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create('Elastic.Channels',
			[Microsoft.CodeAnalysis.SyntaxTree[]]@([Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($source)),
			[Microsoft.CodeAnalysis.MetadataReference[]]@([Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile([object].Assembly.Location)),
			[Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary))
		$file = [IO.File]::Create($stub)
		try {
			$result = $compilation.Emit($file, $null, $null, $compilation.CreateDefaultWin32Resources($true, $true, $null, $null))
		} finally {
			$file.Dispose()
		}
		$result.Success | Should -BeTrue
		$child = @"
Add-Type -Path '$stub'
Import-Module '$root/src/PoShLog.psd1'
try { Import-Module '$root/extensions/PoShLog.Sinks.Elastic/PoShLog.Sinks.Elastic.psd1' -ErrorAction Stop; 'IMPORTED' }
catch { `$_.Exception.Message }
"@
		$output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $child

		$output | Should -Match 'needs Elastic\.Channels 0\.14\.0\.0, but 0\.13\.0\.0 is already loaded'
	}

	It 'refuses to import next to an older Elastic.CommonSchema' {
		$child = @"
`$name = [Reflection.AssemblyName]::new('Elastic.CommonSchema')
`$name.Version = [version]'8.6.0.0'
`$null = [Reflection.Emit.AssemblyBuilder]::DefineDynamicAssembly(`$name, 'Run')
Import-Module '$root/src/PoShLog.psd1'
try { Import-Module '$root/extensions/PoShLog.Sinks.Elastic/PoShLog.Sinks.Elastic.psd1' -ErrorAction Stop; 'IMPORTED' }
catch { `$_.Exception.Message }
"@
		$output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $child

		$output | Should -Match 'needs Elastic\.CommonSchema 9\.0\.0\.0, but 8\.6\.0\.0 is already loaded'
	}
}
