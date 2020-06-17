function Set-LogLevelToPreference {
	param(
		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEventLevel]$LogLevel
	)

	if ([int]$LogLevel -le [int]([Serilog.Events.LogEventLevel]::Verbose)) {
		Set-Variable VerbosePreference -Value 'Continue' -Scope Global
	}
	else{
		Set-Variable VerbosePreference -Value 'SilentlyContinue' -Scope Global
	}

	if ([int]$LogLevel -le [int]([Serilog.Events.LogEventLevel]::Debug)) {
		Set-Variable DebugPreference -Value 'Continue' -Scope Global
	}
	else{
		Set-Variable DebugPreference -Value 'SilentlyContinue' -Scope Global
	}

	if ([int]$LogLevel -le [int]([Serilog.Events.LogEventLevel]::Information)) {
		Set-Variable InformationPreference -Value 'Continue' -Scope Global
	}
	else {
		Set-Variable InformationPreference -Value 'SilentlyContinue' -Scope Global
	}

	if ([int]$LogLevel -le [int]([Serilog.Events.LogEventLevel]::Warning)) {
		Set-Variable WarningPreference -Value 'Continue' -Scope Global
	}
	else{
		Set-Variable WarningPreference -Value 'SilentlyContinue' -Scope Global
	}
}