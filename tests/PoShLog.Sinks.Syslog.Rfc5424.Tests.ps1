#Requires -Version 7.6
# PoShLog.Sinks.Syslog.Rfc5424 end to end: the module as shipped (psd1, psm1, lib) against loopback UDP and TCP receivers.

BeforeAll {
	$root = (Resolve-Path "$PSScriptRoot\..").Path
	$module = Join-Path $root 'extensions/PoShLog.Sinks.Syslog.Rfc5424'
	if (!(Test-Path (Join-Path $module 'lib/PoShLog.Sinks.Syslog.Rfc5424.dll'))) {
		& (Join-Path $root 'build/Build-Extension.ps1') -Module PoShLog.Sinks.Syslog.Rfc5424 | Out-Null
	}
	Import-Module (Join-Path $root 'src/PoShLog.psd1') -Force
	Import-Module (Join-Path $module 'PoShLog.Sinks.Syslog.Rfc5424.psd1') -Force

	function Wait-Datagram([Net.Sockets.UdpClient]$Client, [string]$Marker) {
		$deadline = [datetime]::UtcNow.AddSeconds(20)
		do {
			$receive = $Client.ReceiveAsync()
			if ($receive.Wait([math]::Max(1, ($deadline - [datetime]::UtcNow).TotalMilliseconds))) {
				$text = [Text.Encoding]::UTF8.GetString($receive.Result.Buffer)
				if ($text.Contains($Marker)) { return $text }
			}
		} while ([datetime]::UtcNow -lt $deadline)
		throw "No syslog datagram with $Marker arrived."
	}
}

# Later test files remove PoShLog, which a loaded extension that requires it would block.
AfterAll { Remove-Module PoShLog.Sinks.Syslog.Rfc5424 -ErrorAction SilentlyContinue }

Describe 'Add-SinkSyslog' {
	BeforeEach {
		$script:udp = [Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback, 0))
		$script:port = ([Net.IPEndPoint]$udp.Client.LocalEndPoint).Port
		$script:marker = "syslog-pester-$([guid]::NewGuid().ToString('N'))"
	}
	AfterEach {
		Close-Logger
		$script:udp.Dispose()
	}

	It 'exports only Add-SinkSyslog' {
		(Get-Command -Module PoShLog.Sinks.Syslog.Rfc5424).Name | Should -Be 'Add-SinkSyslog'
	}

	It 'delivers an RFC 5424 datagram with the properties as structured data' {
		New-Logger | Add-SinkSyslog '127.0.0.1' -Port $port -AppName 'pester' -SourceHost 'web01' -BatchInterval 0.1 | Start-Logger
		Write-WarningLog "$marker {User}" -PropertyValues 'tomas'
		Close-Logger

		$datagram = Wait-Datagram $udp $marker
		# Local0 (16) * 8 + Warning (4) = 132.
		$datagram | Should -Match '^<132>1 \S+ web01 pester \d+ - \[poshlog@32473 User="tomas"\] '
		$datagram | Should -BeLike "*$marker tomas"
	}

	It 'delivers octet-counted RFC 3164 frames over TCP' {
		$tcp = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
		$tcp.Start()
		try {
			$accept = $tcp.AcceptTcpClientAsync()
			New-Logger | Add-SinkSyslog '127.0.0.1' -Port ([Net.IPEndPoint]$tcp.LocalEndpoint).Port -Protocol Tcp -Format Rfc3164 -AppName 'pester' `
				-BatchInterval 0.1 | Start-Logger
			Write-InfoLog $marker
			Close-Logger

			$accept.Wait(20000) | Should -BeTrue
			$client = $accept.Result
			$client.ReceiveTimeout = 20000
			$reader = [IO.StreamReader]::new($client.GetStream(), [Text.Encoding]::UTF8)
			$frame = $reader.ReadToEnd()
			$client.Dispose()

			$frame | Should -Match "^\d+ <134>[A-Z][a-z]{2} [ \d]\d \d\d:\d\d:\d\d \S+ pester\[\d+\]: $marker$"
			[int]($frame -split ' ', 2)[0] | Should -Be ([Text.Encoding]::UTF8.GetByteCount(($frame -split ' ', 2)[1]))
		} finally {
			$tcp.Stop()
		}
	}

	It 'imports again into a session that already loaded its assemblies' {
		{ Import-Module (Join-Path $root 'extensions/PoShLog.Sinks.Syslog.Rfc5424/PoShLog.Sinks.Syslog.Rfc5424.psd1') -Force } |
			Should -Not -Throw
		New-Logger | Add-SinkSyslog '127.0.0.1' -Port $port -BatchInterval 0.1 | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Datagram $udp $marker | Should -Not -BeNullOrEmpty
	}

	It 'does not load Serilog.Sinks.PeriodicBatching' {
		New-Logger | Add-SinkSyslog '127.0.0.1' -Port $port -BatchInterval 0.1 | Start-Logger
		Write-InfoLog $marker
		Close-Logger

		Wait-Datagram $udp $marker | Should -Not -BeNullOrEmpty
		[AppDomain]::CurrentDomain.GetAssemblies().GetName().Name | Should -Not -Contain 'Serilog.Sinks.PeriodicBatching'
	}

	It 'refuses to import next to an older Serilog.Sinks.Syslog' {
		# Stands in for the third-party PoShLog.Sinks.Syslog 1.0.0, which ships Serilog.Sinks.SyslogMessages 1.0.5. Both
		# carry assembly version 0.0.0.0, so the stub differs only in its file version. A child process keeps it out of
		# this session.
		$stub = Join-Path $TestDrive 'stub/Serilog.Sinks.Syslog.dll'
		New-Item -ItemType Directory -Force (Split-Path $stub) | Out-Null
		# Roslyn directly, not Add-Type -OutputAssembly: that picks a random assembly name and writes no file version.
		$source = @'
[assembly: System.Reflection.AssemblyVersion("0.0.0.0")]
[assembly: System.Reflection.AssemblyFileVersion("1.0.5.0")]
namespace Serilog.Sinks.Syslog { public static class Stub { } }
'@
		$compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create('Serilog.Sinks.Syslog',
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
try { Import-Module '$root/extensions/PoShLog.Sinks.Syslog.Rfc5424/PoShLog.Sinks.Syslog.Rfc5424.psd1' -ErrorAction Stop; 'IMPORTED' }
catch { `$_.Exception.Message }
"@
		$output = & (Join-Path $PSHOME 'pwsh') -NoProfile -Command $child

		$output | Should -Match 'needs Serilog\.Sinks\.Syslog 4\.1\.0\.0, but 1\.0\.5\.0 is already loaded'
	}
}
