function New-LevelSwitch {
	<#
	.SYNOPSIS
		Creates instance of LoggingLevelSwitch at the initial minimum level
	.DESCRIPTION
		Creates instance of LoggingLevelSwitch that dynamically controls logging level
	.PARAMETER MinimumLevel
		Sets current minimum level, below which no events should be generated
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
		[Serilog.Events.LogEventLevel]$MinimumLevel = [Serilog.Events.LogEventLevel]::Information
	)

	$levelSwitch = [Serilog.Core.LoggingLevelSwitch]::new()
	$levelSwitch.MinimumLevel = $MinimumLevel
	
	$levelSwitch
}