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
	.PARAMETER ToPreference
		Set to propagate desired minimum level to preference variables.
	.PARAMETER PassThru
		Outputs Serilog.Core.LoggingLevelSwitch with updated MinimumLevel into pipeline
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
		[Serilog.Events.LogEventLevel]$MinimumLevel,
		[Parameter(Mandatory = $false)]
		[switch]$ToPreference,
		[Parameter(Mandatory = $false)]
		[switch]$PassThru
	)

	$LevelSwitch.MinimumLevel = $MinimumLevel

	if($ToPreference){
		Set-LogLevelToPreference -LogLevel $MinimumLevel
	}

	if($PassThru){
		$LevelSwitch
	}
}