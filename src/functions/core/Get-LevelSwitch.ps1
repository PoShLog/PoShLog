function Get-LevelSwitch{
	param(
		[Parameter(Mandatory=$false)]
		[Serilog.Events.LogEventLevel]$MinimumLevel = [Serilog.Events.LogEventLevel]::Information
	)

	$levelSwitch = [Serilog.Core.LoggingLevelSwitch]::new()
	$levelSwitch.MinimumLevel = $MinimumLevel
	
	$levelSwitch
}