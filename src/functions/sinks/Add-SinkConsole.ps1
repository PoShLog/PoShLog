function Add-SinkConsole {
	<#
	.SYNOPSIS
		Writes log events to console host
	.DESCRIPTION
		Writes log events to console host
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER RestrictedToMinimumLevel
		The minimum level for events passed through the sink. Ignored when LevelSwitch is specified.
	.PARAMETER OutputTemplate
		A message template describing the format used to write to the sink.
	.PARAMETER FormatProvider
		Supplies culture-specific formatting information, or null.
	.PARAMETER LevelSwitch
		A switch allowing the pass-through minimum level to be changed at runtime.
	.PARAMETER StandardErrorFromLevel
		Specifies the level at which events will be written to standard error.
	.PARAMETER Theme
		The theme to apply to the styled output. If not specified uses Serilog.Sinks.SystemConsole.Themes.SystemConsoleTheme.Literate.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> Add-SinkConsole
	.EXAMPLE
		PS> Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose 
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,
		[Parameter(Mandatory = $false)]
		[string]$OutputTemplate = '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{ErrorRecord}{Exception}',
		[Parameter(Mandatory = $false)]
		[System.IFormatProvider]$FormatProvider = $null,
		[Parameter(Mandatory = $false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null,
		[Parameter(Mandatory = $false)]
		[Nullable[Serilog.Events.LogEventLevel]]$StandardErrorFromLevel = $null,
		[Parameter(Mandatory = $false)]
		[Serilog.Sinks.SystemConsole.Themes.ConsoleTheme]$Theme
	)

	process {	
		$LoggerConfig = [Serilog.ConsoleLoggerConfigurationExtensions]::Console($LoggerConfig.WriteTo,
			$RestrictedToMinimumLevel,
			$OutputTemplate,
			$FormatProvider,
			$LevelSwitch,
			$StandardErrorFromLevel,
			$Theme
		)

		$LoggerConfig
	}
}