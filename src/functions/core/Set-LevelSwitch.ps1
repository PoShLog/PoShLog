function Set-LevelSwitch{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch,
		[Parameter(Mandatory=$true)]
		[Serilog.Events.LogEventLevel]$MinimumLevel
	)

	$LevelSwitch.MinimumLevel = $MinimumLevel

	$LevelSwitch
}