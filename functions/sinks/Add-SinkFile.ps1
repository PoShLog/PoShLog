function Add-SinkFile{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory=$true)]
		[string]$Path,
		[Parameter(Mandatory=$false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,
		[Parameter(Mandatory=$false)]
		[string]$OutputTemplate = '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}',
		[Parameter(Mandatory=$false)]
		[System.IFormatProvider]$FormatProvider = $null,
		[Parameter(Mandatory=$false)]
		[Nullable[long]]$FileSizeLimitBytes = [long]'1073741824',
		[Parameter(Mandatory=$false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null,
		[Parameter(Mandatory=$false)]
		[switch]$Buffered,
		[Parameter(Mandatory=$false)]
		[switch]$Shared,
		[Parameter(Mandatory=$false)]
		[Nullable[timespan]]$FlushToDiskInterval = $null,
		[Parameter(Mandatory=$false)]
		[Serilog.RollingInterval]$RollingInterval = [Serilog.RollingInterval]::Infinite,
		[Parameter(Mandatory=$false)]
		[switch]$RollOnFileSizeLimit,
		[Parameter(Mandatory=$false)]
		[Nullable[int]]$RetainedFileCountLimit = 31,
		[Parameter(Mandatory=$false)]
		[System.Text.Encoding]$Encoding = $null
	)

	process{
		$LoggerConfig = [Serilog.FileLoggerConfigurationExtensions]::File($loggerConfig.WriteTo, 
			$Path, 
			$RestrictedToMinimumLevel,
			$OutputTemplate,
			$FormatProvider,
			$FileSizeLimitBytes,
			$LevelSwitch,
			$Buffered,
			$Shared,
			$FlushToDiskInterval,
			$RollingInterval,
			$RollOnFileSizeLimit,
			$RetainedFileCountLimit,
			$Encoding
		)

		$LoggerConfig
	}
}