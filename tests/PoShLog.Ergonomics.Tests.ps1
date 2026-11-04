#Requires -Version 7.6
# Structured logging of PowerShell objects: issues #46, #34, #48, #45 and #28 (ADRs 0005-0008).

BeforeAll {
	$script:manifest = (Resolve-Path "$PSScriptRoot\..\src\PoShLog.psd1").Path
	Import-Module $script:manifest -Force

	# Runs a script in a fresh pwsh with the module imported and returns everything it printed,
	# so console and transcript behaviour is tested in a real console host.
	function Invoke-ChildPwsh([string]$Body) {
		$script = Join-Path $TestDrive "child-$([guid]::NewGuid()).ps1"
		Set-Content -Path $script -Value "Import-Module '$($script:manifest)'`n$Body"
		# $PSHOME, not the process path: under a dotnet-tool pwsh (the minimum PowerShell CI job) the process is dotnet.
		$pwsh = Join-Path $PSHOME 'pwsh'
		& $pwsh -NoProfile -NonInteractive -File $script 2>&1 | ForEach-Object { "$_" }
	}
}

Describe 'PSObject destructuring (#46)' {
	BeforeEach {
		$script:log = Join-Path $TestDrive "psobj-$([guid]::NewGuid()).log"
		New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkFile -Path $script:log -OutputTemplate '{Message:lj}{NewLine}' | Start-Logger
	}
	AfterEach { Close-Logger }

	It 'logs a Select-Object calculated property as its value' {
		$service = [pscustomobject]@{ Name = 'EventLog'; Status = 'Running' } |
			Select-Object Name, Status, @{ l = 'canControl'; e = { 'canControl' } }

		Write-InformationLog 'Service {@name} is {@hrID} and {@canControl} because {@Status}.' `
			-PropertyValues $service.Name, $service.Status, $service.canControl, 'off'
		Close-Logger

		Get-Content $script:log -Raw | Should -Be "Service EventLog is Running and canControl because off.$([Environment]::NewLine)"
	}

	It 'logs a PSCustomObject that contains a cycle without hanging' {
		$a = [pscustomobject]@{ Name = 'a' }
		$b = [pscustomobject]@{ Name = 'b'; Peer = $a }
		$a | Add-Member -NotePropertyName Peer -NotePropertyValue $b

		Write-InformationLog 'Cycle {@Node}' -PropertyValues $a
		Close-Logger

		Get-Content $script:log -Raw | Should -BeLike '*Cycle {"Name":"a","Peer":{"Name":"b","Peer":"`[Circular`]"}}*'
	}

	It 'logs a hashtable as a JSON object' {
		Write-InformationLog 'Processed {@Position}' -PropertyValues ([ordered]@{ Latitude = 25; Longitude = 134 })
		Close-Logger

		Get-Content $script:log -Raw | Should -BeLike '*Processed {"Latitude":25,"Longitude":134}*'
	}
}

Describe 'Push-LogContextProperty (#34)' {
	BeforeEach {
		$script:log = Join-Path $TestDrive "context-$([guid]::NewGuid()).log"
		New-Logger | Add-EnrichFromLogContext | Add-SinkFile -Path $script:log -Formatter (Get-CompactFormatter) | Start-Logger
	}
	AfterEach { Close-Logger }

	It 'adds the property inside the script block and removes it afterwards' {
		Push-LogContextProperty -Name RunId -Value 42 -ScriptBlock { Write-InfoLog 'inside' }
		Write-InfoLog 'outside'
		Close-Logger

		$events = Get-Content $script:log | ConvertFrom-Json
		$events[0].RunId | Should -Be 42
		$events[1].PSObject.Properties.Name | Should -Not -Contain 'RunId'
	}

	It 'returns a bookmark that removes the property when disposed' {
		$bookmark = Push-LogContextProperty Job nightly
		try { Write-InfoLog 'with job' } finally { $bookmark.Dispose() }
		Write-InfoLog 'without job'
		Close-Logger

		$events = Get-Content $script:log | ConvertFrom-Json
		$events[0].Job | Should -Be 'nightly'
		$events[1].PSObject.Properties.Name | Should -Not -Contain 'Job'
	}
}

Describe 'Get-CompactFormatter (#48)' {
	It 'writes one CLEF object per line to a file sink' {
		$log = Join-Path $TestDrive 'clef.log'
		New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkFile -Path $log -Formatter (Get-CompactFormatter) | Start-Logger
		Write-InfoLog 'Hello {Name}' -PropertyValues 'World'
		Write-WarningLog 'Careful'
		Close-Logger

		$events = Get-Content $log | ConvertFrom-Json
		$events.Count | Should -Be 2
		$events[0].'@mt' | Should -Be 'Hello {Name}'
		$events[0].Name | Should -Be 'World'
		$events[1].'@l' | Should -Be 'Warning'
	}

	It 'writes the rendered message with -Rendered' {
		$log = Join-Path $TestDrive 'clef-rendered.log'
		New-Logger | Add-SinkFile -Path $log -Formatter (Get-CompactFormatter -Rendered) | Start-Logger
		Write-InfoLog 'Hello {Name}' -PropertyValues 'World'
		Close-Logger

		$event = Get-Content $log | ConvertFrom-Json
		$event.'@m' | Should -Be 'Hello "World"'
		$event.'@i' | Should -Match '^[0-9a-f]{8}$'
	}
}

Describe 'Console and transcript (#45, #28)' {
	It 'writes warning, error and fatal events to the console and the transcript alike' {
		$transcript = Join-Path $TestDrive 'transcript.txt'
		$console = Invoke-ChildPwsh @"
Start-Transcript -Path '$transcript' | Out-Null
New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkPowerShell | Start-Logger
Write-InfoLog 'hidden-info-marker'
Write-WarningLog 'warning-marker'
Write-ErrorLog 'error-marker'
Write-FatalLog 'fatal-marker'
Close-Logger
Stop-Transcript | Out-Null
"@
		$transcribed = Get-Content $transcript -Raw

		foreach ($marker in 'warning-marker', 'error-marker', 'fatal-marker') {
			($console -join "`n") | Should -BeLike "*$marker*"
			$transcribed | Should -BeLike "*$marker*"
		}
		($console -join "`n") | Should -Not -BeLike '*hidden-info-marker*'
		$transcribed | Should -Not -BeLike '*hidden-info-marker*'
	}

	It 'prints each event once with Start-Logger -Console' {
		$console = Invoke-ChildPwsh @"
Start-Logger -Console
Write-WarningLog 'once-marker'
Close-Logger
"@
		@($console | Where-Object { $_ -like '*once-marker*' }).Count | Should -Be 1
	}
}
