#Requires -Version 7.4
# Structured logging of PowerShell objects: issue #46 (ADR 0005).

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
