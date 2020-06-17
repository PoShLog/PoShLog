function New-LevelSwitch {
	<#
	.SYNOPSIS
		Creates instance of LoggingLevelSwitch at the initial minimum level
	.DESCRIPTION
		Creates instance of LoggingLevelSwitch that dynamically controls logging level
	.PARAMETER MinimumLevel
		Sets current minimum level, below which no events should be generated
	.PARAMETER ToPreference
		Set to propagate desired minimum level to preference variables. 
	.INPUTS
		None. You cannot pipe objects to New-LevelSwitch
	.OUTPUTS
		Instance of LoggingLevelSwitch with altered minumum logging level
	.EXAMPLE
		PS> $levelSwitch = New-LevelSwitch
	.EXAMPLE
		PS> $levelSwitch = New-LevelSwitch -MinimumLevel Verbose
	#>

	param(
		[Parameter(Mandatory = $false)]
		[Serilog.Events.LogEventLevel]$MinimumLevel = [Serilog.Events.LogEventLevel]::Information,
		[Parameter(Mandatory = $false)]
		[switch]$ToPreference
	)

	$levelSwitch = [Serilog.Core.LoggingLevelSwitch]::new()
	$levelSwitch.MinimumLevel = $MinimumLevel
	
	if($ToPreference){
		Set-LogLevelToPreference -LogLevel $MinimumLevel
	}

	$levelSwitch
}