function Set-LevelSwitch {
	<#
	.SYNOPSIS
		Sets minimum level of given level switch
	.DESCRIPTION
		Sets minimum level of given level switch.
	.PARAMETER LevelSwitch
		Instance of LoggingLevelSwitch to change
	.PARAMETER MinimumLevel
		Sets current minimum level, below which no events should be generated
	.INPUTS
		Instance of LoggingLevelSwitch
	.OUTPUTS
		Instance of LoggingLevelSwitch with altered minumum logging level
	.EXAMPLE
		PS> $levelSwitch | Set-LevelSwitch -MinimumLevel Information
	.EXAMPLE
		PS> $levelSwitch = Set-LevelSwitch -LevelSwitch $levelSwitch -MinimumLevel Information
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch,
		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEventLevel]$MinimumLevel
	)

	$LevelSwitch.MinimumLevel = $MinimumLevel

	$LevelSwitch
}