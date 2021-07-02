function Add-SinkLogger {
	<#
	.SYNOPSIS
		Write log events to a sub-logger
	.DESCRIPTION
		Write log events to a sub-logger, where further processing may occur.
		Events through the sub-logger will be constrained by filters and enriched by enrichers that are active in the parent. 
		A sub-logger cannot be used to log at a more verbose level, but a less verbose level is possible.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER Logger
		The sub-logger. This sub-logger will NOT be shut down automatically when the parent logger is disposed.
	.PARAMETER RestrictedToMinimumLevel
		The minimum level for events passed through the sink. Ignored when LevelSwitch is specified.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> New-Logger | Add-SinkLogger -Logger $logger2 | Start-Logger
	#>

	[OutputType([Serilog.LoggerConfiguration])]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,

		[Parameter(Mandatory = $true)]
		[Serilog.ILogger]$Logger,

		[Parameter(Mandatory = $false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose
	)

	process {

		$LoggerConfig = $LoggerConfig.WriteTo.Logger($Logger, $RestrictedToMinimumLevel)

		$LoggerConfig
	}
}