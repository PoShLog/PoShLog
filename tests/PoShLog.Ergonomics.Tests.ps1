#Requires -Version 7.4
# Structured logging of PowerShell objects: issues #46 and #48 (ADRs 0005 and 0007).

BeforeAll {
	$script:manifest = (Resolve-Path "$PSScriptRoot\..\src\PoShLog.psd1").Path
	Import-Module $script:manifest -Force

	# Runs a script in a fresh pwsh with the module imported and returns everything it printed,
	# so console and transcript behaviour is tested in a real console host.
	function Invoke-ChildPwsh([string]$Body) {
		$script = Join-Path $TestDrive "child-$([guid]::NewGuid()).ps1"
		Set-Content -Path $script -Value "Import-Module '$($script:manifest)'`n$Body"
		$pwsh = (Get-Process -Id $PID).Path
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
