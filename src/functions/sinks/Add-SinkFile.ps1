function Add-SinkFile {
	<#
	.SYNOPSIS
		Write log events to the specified file
	.DESCRIPTION
		Write log events to the specified file
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER Path
		Path to the file.
	.PARAMETER Formatter
		A formatter, such as JsonFormatter(See Get-JsonFormatter), to convert the log events into text for the file. If control of regular text formatting is required, use Default parameter set.
	.PARAMETER RestrictedToMinimumLevel
		The minimum level for events passed through the sink. Ignored when LevelSwitch is specified.
	.PARAMETER OutputTemplate
		A message template describing the format used to write to the sink.
	.PARAMETER FormatProvider
		Supplies culture-specific formatting information, or null.
	.PARAMETER FileSizeLimitBytes
		The approximate maximum size, in bytes, to which a log file will be allowed to grow. For unrestricted growth, pass null. The default is 1 GB. To avoid writing partial events, the last event within the limit will be written in full even if it exceeds the limit.
	.PARAMETER LevelSwitch
		A switch allowing the pass-through minimum level to be changed at runtime.
	.PARAMETER Buffered
		Indicates if flushing to the output file can be buffered or not. The default is false.
	.PARAMETER Shared
		Allow the log file to be shared by multiple processes. The default is false.
	.PARAMETER FlushToDiskInterval
		If provided, a full disk flush will be performed periodically at the specified interval.
	.PARAMETER RollingInterval
		The interval at which logging will roll over to a new file.
	.PARAMETER RollOnFileSizeLimit
		If true, a new file will be created when the file size limit is reached. Filenames will have a number appended in the format _NNN, with the first filename given no number.
	.PARAMETER RetainedFileCountLimit
		The maximum number of log files that will be retained, including the current log file. For unlimited retention, pass null. The default is 31.
	.PARAMETER Encoding
		Character encoding used to write the text file. The default is UTF-8 without BOM.
	.PARAMETER Hooks
		Optionally enables hooking into log file lifecycle events.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> New-Logger | Add-SinkFile -Path "C:\Logs\test.log" | Start-Logger
	.EXAMPLE
		PS> New-Logger | Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' | Start-Logger
	.EXAMPLE
		PS> New-Logger | Add-SinkFile -Path 'C:\Data\Log\test.log' -Formatter (Get-JsonFormatter) | Start-Logger
	#>

	[Cmdletbinding(DefaultParameterSetName = 'Default')]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,

		[Parameter(Mandatory = $true)]
		[string]$Path,

		[Parameter(Mandatory = $true, ParameterSetName = 'Formatter')]
		[Serilog.Formatting.ITextFormatter]$Formatter,

		[Parameter(Mandatory = $false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,

		[Parameter(Mandatory = $false)]
		[string]$OutputTemplate = '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception}{ErrorRecord}',

		[Parameter(Mandatory = $false, ParameterSetName = 'Default')]
		[System.IFormatProvider]$FormatProvider = $null,

		[Parameter(Mandatory = $false)]
		[Nullable[long]]$FileSizeLimitBytes = [long]'1073741824',

		[Parameter(Mandatory = $false)]
		[Serilog.Core.LoggingLevelSwitch]$LevelSwitch = $null,

		[Parameter(Mandatory = $false)]
		[switch]$Buffered,

		[Parameter(Mandatory = $false)]
		[switch]$Shared,

		[Parameter(Mandatory = $false)]
		[Nullable[timespan]]$FlushToDiskInterval = $null,

		[Parameter(Mandatory = $false)]
		[Serilog.RollingInterval]$RollingInterval = [Serilog.RollingInterval]::Infinite,

		[Parameter(Mandatory = $false)]
		[switch]$RollOnFileSizeLimit,

		[Parameter(Mandatory = $false)]
		[Nullable[int]]$RetainedFileCountLimit = 31,

		[Parameter(Mandatory = $false)]
		[System.Text.Encoding]$Encoding = $null,

		[Parameter(Mandatory = $false)]
		[Serilog.Sinks.File.FileLifecycleHooks]$Hooks = $null
	)

	process {

		switch ($PSCmdlet.ParameterSetName) {
			'Default' {
				$LoggerConfig = [Serilog.FileLoggerConfigurationExtensions]::File($LoggerConfig.WriteTo, 
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
					$Encoding,
					$Hooks
				)
			}
			'Formatter' {
				$LoggerConfig = [Serilog.FileLoggerConfigurationExtensions]::File($LoggerConfig.WriteTo, 
					$Formatter,
					$Path, 
					$RestrictedToMinimumLevel,
					$FileSizeLimitBytes,
					$LevelSwitch,
					$Buffered,
					$Shared,
					$FlushToDiskInterval,
					$RollingInterval,
					$RollOnFileSizeLimit,
					$RetainedFileCountLimit,
					$Encoding,
					$Hooks
				)
			}
		}

		$LoggerConfig
	}
}