function Add-SinkSeq {
	<#
	.SYNOPSIS
		Writes log events into seq
	.DESCRIPTION
		Writes log events into seq server
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER ServerUrl
		The base URL of the Seq server that log events will be written to.
	.PARAMETER RestrictedToMinimumLevel
		The minimum level for events passed through the sink. Ignored when LevelSwitch is specified.
	.PARAMETER BatchPostingLimit
		The maximum number of events to post in a single batch.
	.PARAMETER Period
		The time to wait between checking for event batches
	.PARAMETER ApiKey
		A Seq API key that authenticates the client to the Seq server
	.PARAMETER BufferSizeLimitBytes
		The maximum amount of data, in bytes, to which the buffer log file for a specific date will be allowed to grow. By default no limit will be applied.
	.PARAMETER EventBodyLimitBytes
		The maximum size, in bytes, that the JSON representation of an event may take before it is dropped rather than being sent to the Seq server. Specify null for no limit.
	.PARAMETER ControlLevelSwitch
		If provided, the switch will be updated based on the Seq server's level setting
		for the corresponding API key. Passing the same key to MinimumLevel.ControlledBy() will make the whole pipeline
		dynamically controlled. Do not specify parameter RestrictedToMinimumLevel with this setting.
	.PARAMETER MessageHandler
		Used to construct the HttpClient that will send the log messages to Seq.
	.PARAMETER RetainedInvalidPayloadsLimitBytes
		A soft limit for the number of bytes to use for storing failed requests.
		The limit is soft in that it can be exceeded by any single error payload, but in that case only that single error payload will be retained.
	.PARAMETER Compact
		Use the compact log event format defined by Serilog.Formatting.Compact. Has no effect on durable log shipping.
	.PARAMETER QueueSizeLimit
		The maximum number of events that will be held in-memory while waiting to ship them to Seq.
		Beyond this limit, events will be dropped. The default is 100,000. Has no effect on durable log shipping.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> New-Logger | Add-SinkSeq -ServerUrl 'http://localhost:5341' | Start-Logger
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,

		[Parameter(Mandatory = $true)]
		[string]$ServerUrl,

		[Parameter(Mandatory = $false, ParameterSetName = 'RestrictedToMinimumLevel')]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,

		[Parameter(Mandatory = $false)]
		[int]$BatchPostingLimit = 1000,

		[Parameter(Mandatory = $false)]
		[Nullable[System.Timespan]]$Period = $null,

		[Parameter(Mandatory = $false)]
		[string]$ApiKey,

		[Parameter(Mandatory = $false)]
		[Nullable[long]]$BufferSizeLimitBytes,

		[Parameter(Mandatory = $false)]
		[Nullable[long]]$EventBodyLimitBytes = 262144L,

		[Parameter(Mandatory = $false)]
		[Serilog.Core.LoggingLevelSwitch]$ControlLevelSwitch = $null,

		[Parameter(Mandatory = $false)]
		[System.Net.Http.HttpMessageHandler]$MessageHandler = $null,

		[Parameter(Mandatory = $false)]
		[Nullable[long]]$RetainedInvalidPayloadsLimitBytes = $null,

		[Parameter(Mandatory = $false)]
		[bool]$Compact = $false,

		[Parameter(Mandatory = $false)]
		[int]$QueueSizeLimit = 100000
	)

	process {
		# Seq 9 uses a payload formatter instead of the former compact flag.
		$payloadFormatter = if ($Compact) { $null } else { [Serilog.Formatting.Json.JsonFormatter]::new() }
		$LoggerConfig = [Serilog.SeqLoggerConfigurationExtensions]::Seq($LoggerConfig.WriteTo,
			$ServerUrl,
			$RestrictedToMinimumLevel,
			$BatchPostingLimit,
			$Period,
			$ApiKey,
			[System.Management.Automation.Language.NullString]::Value, # Keep the sink non-durable.
			$BufferSizeLimitBytes,
			$EventBodyLimitBytes,
			$ControlLevelSwitch,
			$MessageHandler,
			$RetainedInvalidPayloadsLimitBytes,
			$QueueSizeLimit,
			$payloadFormatter,
			$null
		)

		$LoggerConfig
	}
}
