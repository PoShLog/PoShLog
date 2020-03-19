function Add-SinkConsole{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig,
		[Parameter(Mandatory=$false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,
		[Parameter(Mandatory=$false)]
		[string]$OutputTemplate = '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}',
		[Parameter(Mandatory=$false)]
		[System.IFormatProvider]$FormatProvider = $null,
		[Parameter(Mandatory=$false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null,
		[Parameter(Mandatory=$false)]
		[Nullable[Serilog.Events.LogEventLevel]]$StandardErrorFromLevel = $null,
		[Parameter(Mandatory=$false)]
		[Serilog.Sinks.SystemConsole.Themes.ConsoleTheme]$Theme
	)

	process{	
		$loggerConfig = [Serilog.ConsoleLoggerConfigurationExtensions]::Console($loggerConfig.WriteTo,
			$RestrictedToMinimumLevel,
			$OutputTemplate,
			$FormatProvider,
			$LevelSwitch,
			$StandardErrorFromLevel,
			$Theme
		)

		$loggerConfig
	}
}