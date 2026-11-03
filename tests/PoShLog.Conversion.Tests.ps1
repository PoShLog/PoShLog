BeforeAll {
	Import-Module "$PSScriptRoot\..\src\PoShLog.psd1" -Force
	function Set-InputScript([string]$Text) {
		$script:inputPath = Join-Path $TestDrive ($([guid]::NewGuid()).ToString() + '-input.ps1')
		[IO.File]::WriteAllText($script:inputPath, $Text, (New-Object Text.UTF8Encoding $false))
	}
}

Describe 'Safe Convert-LogFunctions' {
	It 'changes command names and parameters only, preserving literal text and definitions' {
		$text = @'
# Write-Warning -Message comment
$s = 'Write-Verbose -Message string'
$h = @"
Write-Debug here-string
"@
function Write-Verbose { 'definition' }
wRiTe-WaRnInG -mEs 'hello' # Write-Information comment
'@
		Set-InputScript $text
		$result = @(Convert-LogFunctions -FilePath $inputPath)
		$result.Count | Should -Be 1
		$result[0].Action | Should -Be 'Converted'
		[IO.File]::ReadAllText($inputPath) | Should -Be ($text.Replace('wRiTe-WaRnInG -mEs', 'Write-WarningLog -MessageTemplate'))
		[IO.File]::ReadAllText("$inputPath.bak") | Should -Be $text
	}

	It 'skips unsafe call: <Text>' -ForEach @(
		@{ Text = "Write-Error -Message 'failure'" }
		@{ Text = "Write-Host 'hello' -ForegroundColor Red" }
		@{ Text = "Write-Host 'hello' -NoNewline" }
		@{ Text = "Write-Information 'hello' -Tags tag" }
		@{ Text = 'Write-Warning @arguments' }
		@{ Text = "'hello' | Write-Warning" }
		@{ Text = "Write-Host 'hello' 'world'" }
		@{ Text = "Write-Warning -in Continue 'hello'" }
		@{ Text = "Write-Warning 'hello' 3> warnings.txt" }
		@{ Text = "& 'Write-Warning' 'hello'" }
		@{ Text = 'Write-Warning' }
		@{ Text = '$s = "$(Write-Warning ''embedded'')"' }
	) {
		Set-InputScript $Text
		$result = @(Convert-LogFunctions -FilePath $inputPath)
		$result.Count | Should -Be 1
		$result[0].Action | Should -Be 'Skipped'
		[IO.File]::ReadAllText($inputPath) | Should -Be $Text
		Test-Path -LiteralPath "$inputPath.bak" | Should -BeFalse
	}

	It 'maps supported parameters: <Text>' -ForEach @(
		@{ Text = "Write-Verbose -Mes:'hello'"; Expected = "Write-VerboseLog -MessageTemplate:'hello'" }
		@{ Text = "Write-Debug 'hello' -ea Stop"; Expected = "Write-DebugLog 'hello' -ErrorAction Stop" }
		@{ Text = "Write-Information -MessageD 'hello'"; Expected = "Write-InfoLog -MessageTemplate 'hello'" }
		@{ Text = "Write-Host -Obj 'hello'"; Expected = "Write-InfoLog -MessageTemplate 'hello'" }
	) {
		Set-InputScript $Text
		Get-Item -LiteralPath $inputPath | Convert-LogFunctions | Out-Null
		[IO.File]::ReadAllText($inputPath) | Should -Be $Expected
	}

	It 'does not write or back up with WhatIf and reports the proposed change' {
		Set-InputScript "Write-Warning 'hello'"
		$result = Convert-LogFunctions -FilePath $inputPath -WhatIf
		$result.Action | Should -Be 'Skipped'
		$result.After | Should -Be "Write-WarningLog 'hello'"
		[IO.File]::ReadAllText($inputPath) | Should -Be "Write-Warning 'hello'"
		Test-Path -LiteralPath "$inputPath.bak" | Should -BeFalse
	}

	It 'preserves bytes, BOM, mixed newlines and the original backup: <Kind>' -ForEach @(
		@{ Kind = 'utf8' }; @{ Kind = 'utf8bom' }; @{ Kind = 'utf16le' }; @{ Kind = 'utf16be' }; @{ Kind = 'utf32le' }; @{ Kind = 'utf32be' }
	) {
		$encoding = switch ($Kind) {
			'utf8' { New-Object Text.UTF8Encoding $false }
			'utf8bom' { New-Object Text.UTF8Encoding $true }
			'utf16le' { [Text.Encoding]::Unicode }
			'utf16be' { [Text.Encoding]::BigEndianUnicode }
			'utf32le' { [Text.Encoding]::UTF32 }
			'utf32be' { New-Object Text.UTF32Encoding $true, $true }
		}
		$text = "# caf$([char]0xe9)`r`nWrite-Warning 'hello'`nWrite-Debug 'ok'"
		Set-InputScript $text
		$original = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes($text))
		[IO.File]::WriteAllBytes($inputPath, $original)
		Convert-LogFunctions -FilePath $inputPath | Out-Null
		$expected = [byte[]]($encoding.GetPreamble() + $encoding.GetBytes($text.Replace('Write-Warning', 'Write-WarningLog').Replace('Write-Debug', 'Write-DebugLog')))
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($inputPath)) | Should -Be ([Convert]::ToBase64String($expected))
		[Convert]::ToBase64String([IO.File]::ReadAllBytes("$inputPath.bak")) | Should -Be ([Convert]::ToBase64String($original))
	}

	It 'refuses parse errors and invalid encoding without writing' -ForEach @(@{ InvalidEncoding = $false }; @{ InvalidEncoding = $true }) {
		Set-InputScript "Write-Warning 'hello'`nif ("
		if ($InvalidEncoding) { [IO.File]::WriteAllBytes($inputPath, [byte[]]([Text.Encoding]::UTF8.GetBytes("Write-Warning 'hello' # ") + 255)) }
		$original = [Convert]::ToBase64String([IO.File]::ReadAllBytes($inputPath))
		{ Convert-LogFunctions -FilePath $inputPath -ErrorAction Stop } | Should -Throw
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($inputPath)) | Should -Be $original
		Test-Path -LiteralPath "$inputPath.bak" | Should -BeFalse
	}

	It 'requires Force to overwrite an existing backup' {
		Set-InputScript "Write-Warning 'hello'"
		[IO.File]::WriteAllText("$inputPath.bak", 'previous backup')
		{ Convert-LogFunctions -FilePath $inputPath -ErrorAction Stop } | Should -Throw
		[IO.File]::ReadAllText($inputPath) | Should -Be "Write-Warning 'hello'"
		[IO.File]::ReadAllText("$inputPath.bak") | Should -Be 'previous backup'
		Convert-LogFunctions -FilePath $inputPath -Force -Confirm:$false | Out-Null
		[IO.File]::ReadAllText("$inputPath.bak") | Should -Be "Write-Warning 'hello'"
		[IO.File]::ReadAllText($inputPath) | Should -Be "Write-WarningLog 'hello'"
	}

	It 'handles multiple pipeline paths and returns findings in source order' {
		Set-InputScript "Write-Error 'one'`nWrite-Warning 'two'; Write-Error 'three'"
		$first = $inputPath
		Set-InputScript "Write-Debug 'four'"
		$result = @($first, $inputPath | Convert-LogFunctions -Confirm:$false)
		($result.Action -join ',') | Should -Be 'Skipped,Converted,Skipped,Converted'
		($result.Line -join ',') | Should -Be '1,2,2,1'
	}

	It 'treats wildcard characters in paths literally' {
		$path = Join-Path $TestDrive 'literal[1].ps1'
		[IO.File]::WriteAllText($path, "Write-Warning 'hello'")
		Convert-LogFunctions -Path $path | Out-Null
		[IO.File]::ReadAllText($path) | Should -Be "Write-WarningLog 'hello'"
		[IO.File]::ReadAllText("$path.bak") | Should -Be "Write-Warning 'hello'"
	}

	It 'preserves commands embedded in expandable here-strings' {
		$text = @'
$h = @"
$(Write-Debug 'embedded')
"@
'@
		Set-InputScript $text
		$result = Convert-LogFunctions -FilePath $inputPath
		$result.Action | Should -Be 'Skipped'
		[IO.File]::ReadAllText($inputPath) | Should -Be $text
		Test-Path -LiteralPath "$inputPath.bak" | Should -BeFalse
	}
}

