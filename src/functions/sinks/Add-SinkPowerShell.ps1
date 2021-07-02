function Add-SinkPowerShell {
	<#
	.SYNOPSIS
		Writes log events to powershell host
	.DESCRIPTION
		Writes log events to powershell host
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER RestrictedToMinimumLevel
		The minimum level for events passed through the sink. Ignored when LevelSwitch is specified.
	.PARAMETER OutputTemplate
		A message template describing the format used to write to the sink.
	.PARAMETER LevelSwitch
		A switch allowing the pass-through minimum level to be changed at runtime.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> Add-SinkPowerShell
	.EXAMPLE
		PS> Add-SinkPowerShell -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}"
	#>

	[OutputType([Serilog.LoggerConfiguration])]
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,

		[Parameter(Mandatory = $false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,

		[Parameter(Mandatory = $false)]
		[string]$OutputTemplate = '{Message:lj}{ErrorRecord}',
		
		[Parameter(Mandatory = $false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null
	)

	process {	
		$LoggerConfig = [PoShLog.Core.Sinks.Extensions.PowerShellSinkExtensions]::PowerShell($LoggerConfig.WriteTo, 
			{ param([Serilog.Events.LogEvent]$logEvent, [string]$renderedMessage) Write-SinkPowerShell -LogEvent $logEvent -RenderedMessage $renderedMessage },
			$RestrictedToMinimumLevel,
			$OutputTemplate,
			$LevelSwitch
		)

		$LoggerConfig
	}
}