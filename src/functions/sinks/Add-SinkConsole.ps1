function Add-SinkConsole {
	<#
	.SYNOPSIS
		Writes log events to console host
	.DESCRIPTION
		Writes log events to the process console. Start-Transcript does not capture this sink.
		Use Add-SinkPowerShell for PowerShell streams and transcript support.
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
	.PARAMETER Formatter
		An ITextFormatter, such as Get-JsonFormatter, that formats console events.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> Add-SinkConsole
	.EXAMPLE
		PS> Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose 
	#>

	[OutputType([Serilog.LoggerConfiguration])]
	[Cmdletbinding(DefaultParameterSetName = 'Default')]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,
		[Parameter(Mandatory = $false, ParameterSetName = 'Default')]
		[string]$OutputTemplate = '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{ErrorRecord}{Exception}',
		[Parameter(Mandatory = $false, ParameterSetName = 'Default')]
		[System.IFormatProvider]$FormatProvider = $null,
		[Parameter(Mandatory = $false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null,
		[Parameter(Mandatory = $false)]
		[Nullable[Serilog.Events.LogEventLevel]]$StandardErrorFromLevel = $null,
		[Parameter(Mandatory = $false, ParameterSetName = 'Default')]
		[Serilog.Sinks.SystemConsole.Themes.ConsoleTheme]$Theme = $null,
		[Parameter(Mandatory = $true, ParameterSetName = 'Formatter')]
		[ValidateNotNull()]
		[Serilog.Formatting.ITextFormatter]$Formatter
	)

	process {	
		if ($PSCmdlet.ParameterSetName -eq 'Formatter') {
			$LoggerConfig = [Serilog.ConsoleLoggerConfigurationExtensions]::Console(
				$LoggerConfig.WriteTo, $Formatter, $RestrictedToMinimumLevel, $LevelSwitch, $StandardErrorFromLevel)
		} else {
			$LoggerConfig = [Serilog.ConsoleLoggerConfigurationExtensions]::Console([Serilog.Configuration.LoggerSinkConfiguration]$LoggerConfig.WriteTo,
				[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel,
				[string]$OutputTemplate,
				[System.IFormatProvider]$FormatProvider,
				[Serilog.Core.LoggingLevelSwitch]$LevelSwitch,
				[Nullable[Serilog.Events.LogEventLevel]]$StandardErrorFromLevel,
				[Serilog.Sinks.SystemConsole.Themes.ConsoleTheme]$Theme
			)
		}

		$LoggerConfig
	}
}
