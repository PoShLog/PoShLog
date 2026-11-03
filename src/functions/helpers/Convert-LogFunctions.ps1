function Convert-LogFunctions {
	<#
	.SYNOPSIS
		Conservatively converts logging command calls in a script for manual review.
	.DESCRIPTION
		Converts simple Write-Verbose, Write-Debug, Write-Information, Write-Warning and
		Write-Host calls using the PowerShell AST. Strings, comments and Write-Error are
		preserved. Unsupported calls are reported as Skipped. Review the diff before use.
		Creates a .bak backup and preserves Unicode encoding, BOM and line endings.
		BOM-less input must be valid UTF-8; ambiguous legacy encodings are refused.
	.PARAMETER FilePath
		Literal path to a script. Path and FullName are aliases; accepts pipeline input.
	.PARAMETER Force
		Allows replacing an existing .bak backup.
	.OUTPUTS
		Conversion findings with File, Line, Command, Action, Before, After and Reason.
	.EXAMPLE
		Convert-LogFunctions -FilePath C:\myscript.ps1 -WhatIf
	#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('Path', 'FullName')]
		[string]$FilePath,
		[switch]$Force
	)

	begin {
		function Apply-ConversionEdits($Text, $Edits, [int]$Origin = 0) {
			$builder = [Text.StringBuilder]::new($Text)
			foreach ($edit in ($Edits | Sort-Object Offset -Descending)) {
				[void]$builder.Remove($edit.Offset - $Origin, $edit.Length)
				[void]$builder.Insert($edit.Offset - $Origin, $edit.Text)
			}
			$builder.ToString()
		}

		function Get-ConversionSkipReason($Command, $Name, $Target, $Edits) {
			for ($parent = $Command.Parent; $null -ne $parent; $parent = $parent.Parent) {
				if ($parent -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
					return 'Commands inside strings require manual review.'
				}
			}
			if ($Command.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Unknown) {
				return 'Invocation operators require manual review.'
			}
			if ($Command.Parent -is [System.Management.Automation.Language.PipelineAst] -and
				$Command.Parent.PipelineElements[0] -ne $Command) { return 'Pipeline input requires manual review.' }
			if ($Command.Redirections.Count -ne 0) { return 'Stream redirection requires manual review.' }
			if ($Command.FindAll({ param($node) $node -is [System.Management.Automation.Language.VariableExpressionAst] -and $node.Splatted }, $true).Count) {
				return 'Splatting cannot be checked statically.'
			}
			$source = Get-Command "Microsoft.PowerShell.Utility\$Name" -CommandType Cmdlet -ErrorAction Stop
			$targetParameters = (Get-Command $Target -CommandType Function -ErrorAction Stop).Parameters
			$message = switch ($Name) { 'Write-Information' { 'MessageData' }; 'Write-Host' { 'Object' }; default { 'Message' } }
			$positional = 0
			$hasMessage = $false
			for ($i = 1; $i -lt $Command.CommandElements.Count; $i++) {
				$element = $Command.CommandElements[$i]
				if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
					$candidates = @($source.Parameters.Values | Where-Object {
						$_.Name -ieq $element.ParameterName -or $_.Aliases -icontains $element.ParameterName
					})
					if ($candidates.Count -eq 0) {
						$candidates = @($source.Parameters.Values | Where-Object {
							$matchesPrefix = $_.Name.StartsWith($element.ParameterName, [StringComparison]::OrdinalIgnoreCase)
							foreach ($alias in $_.Aliases) { $matchesPrefix = $matchesPrefix -or $alias.StartsWith($element.ParameterName, [StringComparison]::OrdinalIgnoreCase) }
							$matchesPrefix
						})
					}
					if ($candidates.Count -ne 1) { return "Unknown or ambiguous parameter: -$($element.ParameterName)" }
					$resolved = $candidates[0]
					$isMessage = $resolved.Name -ieq $message
					if (-not $isMessage -and -not $targetParameters.ContainsKey($resolved.Name)) {
						return "Target function does not support parameter -$($resolved.Name)."
					}
					if ($isMessage) { $hasMessage = $true }
					$replacement = if ($isMessage) { 'MessageTemplate' } else { $resolved.Name }
					$Edits.Add([pscustomobject]@{ Offset = $element.Extent.StartOffset; Length = 1 + $element.ParameterName.Length; Text = "-$replacement" })
					if ($resolved.ParameterType -ne [System.Management.Automation.SwitchParameter] -and $null -eq $element.Argument) {
						$i++
						if ($i -ge $Command.CommandElements.Count -or $Command.CommandElements[$i] -is [System.Management.Automation.Language.CommandParameterAst]) {
							return 'Parameter value cannot be determined safely.'
						}
					}
				} else {
					if ($element.Extent.Text -in @('--%', '--')) { return 'Argument parsing markers require manual review.' }
					$positional++
				}
			}
			$maximum = if ($hasMessage) { 0 } else { 1 }
			if ($positional -gt $maximum) { return 'Multiple message arguments require manual review.' }
			if (-not $hasMessage -and $positional -eq 0) { return 'No explicit message was supplied.' }
			$extent = $Command.CommandElements[0].Extent
			$Edits.Add([pscustomobject]@{ Offset = $extent.StartOffset; Length = $extent.EndOffset - $extent.StartOffset; Text = $Target })
		}
	}

	process {
		try {
			$path = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($FilePath)
			$original = [IO.File]::ReadAllBytes($path)
			$reader = [IO.StreamReader]::new([IO.MemoryStream]::new($original), [Text.UTF8Encoding]::new($false, $true), $true)
			try {
				[void]$reader.Peek()
				$encoding = $reader.CurrentEncoding.Clone()
			} finally { $reader.Dispose() }
			$encoding.DecoderFallback = [Text.DecoderFallback]::ExceptionFallback
			$encoding.EncoderFallback = [Text.EncoderFallback]::ExceptionFallback
			$preamble = $encoding.GetPreamble()
			$bom = 0
			if ($preamble.Length -gt 0 -and $original.Length -ge $preamble.Length -and
				[Convert]::ToBase64String($original, 0, $preamble.Length) -eq [Convert]::ToBase64String($preamble)) { $bom = $preamble.Length }
			$text = $encoding.GetString($original, $bom, $original.Length - $bom)
			$tokens = $null
			$parseErrors = $null
			# Parse decoded text so BOM-less UTF-8 has identical offsets on 5.1 and 7.
			$ast = [System.Management.Automation.Language.Parser]::ParseInput($text, $path, [ref]$tokens, [ref]$parseErrors)
			if ($parseErrors.Count -gt 0) { throw [System.Management.Automation.ParseException]::new($parseErrors) }
			$edits = [Collections.Generic.List[object]]::new()
			$findings = [Collections.Generic.List[object]]::new()
			$targets = @{ 'Write-Verbose' = 'Write-VerboseLog'; 'Write-Debug' = 'Write-DebugLog'; 'Write-Information' = 'Write-InfoLog'; 'Write-Host' = 'Write-InfoLog'; 'Write-Warning' = 'Write-WarningLog'; 'Write-Error' = '' }
			foreach ($command in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
				$name = $command.GetCommandName()
				if ($null -eq $name -or -not $targets.ContainsKey($name)) { continue }
				$local = [Collections.Generic.List[object]]::new()
				$reason = if ($name -ieq 'Write-Error') { 'Write-Error must retain PowerShell error semantics.' } else { Get-ConversionSkipReason $command $name $targets[$name] $local }
				$before = $command.Extent.Text
				$after = $before
				$action = 'Skipped'
				if ($null -eq $reason) {
					$after = Apply-ConversionEdits $before $local $command.Extent.StartOffset
					$edits.AddRange($local)
					$action = 'Converted'
					$reason = 'Command and parameter names converted; review before use.'
				}
				$findings.Add([pscustomobject]@{ File = $path; Line = $command.Extent.StartLineNumber; Command = $name; Action = $action; Before = $before; After = $after; Reason = $reason })
			}
			if ($edits.Count -gt 0) {
				if ($PSCmdlet.ShouldProcess($path, "Back up original to $path.bak and convert logging calls")) {
					if ([Convert]::ToBase64String($original) -cne [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))) {
						throw [IO.IOException]::new('The file changed during conversion; no changes were written.')
					}
					$body = $encoding.GetBytes((Apply-ConversionEdits $text $edits))
					$output = [byte[]]::new($bom + $body.Length)
					[Array]::Copy($original, 0, $output, 0, $bom)
					[Array]::Copy($body, 0, $output, $bom, $body.Length)
					[IO.File]::Copy($path, "$path.bak", $Force.IsPresent)
					$temporary = $path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
					try {
						[IO.File]::WriteAllBytes($temporary, $output)
						[IO.File]::Replace($temporary, $path, [System.Management.Automation.Language.NullString]::Value)
					} finally {
						if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
					}
				} else {
					foreach ($finding in $findings) {
						if ($finding.Action -eq 'Converted') {
							$finding.Action = 'Skipped'
							$finding.Reason = 'ShouldProcess declined (WhatIf or confirmation); After shows the proposed change.'
						}
					}
				}
			}
			$findings
		} catch { $PSCmdlet.WriteError($_) }
	}
}
