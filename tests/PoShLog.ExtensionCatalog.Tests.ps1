#Requires -Version 5.1
# Get-PoShLogExtension and Install-PoShLogExtension against the module as users import it (ADR 0021).

BeforeAll {
	Import-Module (Resolve-Path $(if ($env:POSHLOG_TEST_MANIFEST) { $env:POSHLOG_TEST_MANIFEST } else { "$PSScriptRoot\..\src\PoShLog.psd1" })).Path -Force
	$script:manifests = Get-ChildItem "$PSScriptRoot\..\extensions\*\*.psd1" |
		Where-Object { $_.BaseName -eq $_.Directory.Name } |
		ForEach-Object { [pscustomobject]@{ Name = $_.BaseName; Data = Import-PowerShellDataFile $_.FullName } }
}

Describe 'Get-PoShLogExtension' {
	It 'lists every extension in the repository with its version and commands' {
		$listed = Get-PoShLogExtension

		$listed.Name | Should -Be ($script:manifests.Name | Sort-Object)
		foreach ($manifest in $script:manifests) {
			$entry = $listed | Where-Object Name -eq $manifest.Name
			$psData = $manifest.Data.PrivateData.PSData
			$entry.Version | Should -Be "$($manifest.Data.ModuleVersion)-$($psData.Prerelease)"
			$exports = @($manifest.Data.CmdletsToExport) + @($manifest.Data.FunctionsToExport) | Where-Object { $_ -and $_ -notmatch '\*' }
			$entry.Commands | Should -Be $exports
			$entry.CompatiblePSEditions | Should -Be $manifest.Data.CompatiblePSEditions
		}
	}

	It 'names commands that the extension module really exports' {
		$seq = Get-PoShLogExtension -Name PoShLog.Sinks.Seq
		$seq.Commands | Should -Be 'Add-SinkSeq'
		$seq.Kind | Should -Be 'Sink'
	}

	It 'completes extension names' {
		$completion = TabExpansion2 -inputScript 'Install-PoShLogExtension PoShLog.Sinks.S' -cursorColumn 40
		$completion.CompletionMatches.CompletionText | Should -Contain 'PoShLog.Sinks.Seq'
	}
}

Describe 'Install-PoShLogExtension' {
	BeforeEach {
		$script:calls = [System.Collections.Generic.List[object]]::new()
		function global:Install-PSResource {
			param([string]$Name, [switch]$Prerelease, [string]$Scope, [string[]]$Repository, [switch]$TrustRepository, [switch]$PassThru)
			$script:calls.Add($PSBoundParameters)
		}
	}
	AfterEach { Remove-Item function:global:Install-PSResource }

	It 'installs a prerelease while PoShLog is a prerelease' {
		$prerelease = (Import-PowerShellDataFile $(if ($env:POSHLOG_TEST_MANIFEST) { $env:POSHLOG_TEST_MANIFEST } else { "$PSScriptRoot\..\src\PoShLog.psd1" })).PrivateData.PSData.Prerelease

		Install-PoShLogExtension PoShLog.Sinks.Seq -Confirm:$false

		$script:calls.Count | Should -Be 1
		$script:calls[0].Name | Should -Be 'PoShLog.Sinks.Seq'
		$script:calls[0].ContainsKey('Prerelease') | Should -Be ([bool]$prerelease)
	}

	It 'installs nothing with -WhatIf' {
		Install-PoShLogExtension PoShLog.Sinks.Seq -WhatIf

		$script:calls.Count | Should -Be 0
	}

	It 'refuses a module that is not a first-party extension' {
		{ Install-PoShLogExtension Some.Other.Module -ErrorAction Stop } | Should -Throw '*not a first-party PoShLog extension*'
		$script:calls.Count | Should -Be 0
	}
}
