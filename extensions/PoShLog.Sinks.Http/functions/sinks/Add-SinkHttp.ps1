function Add-SinkHttp {
	<#
	.SYNOPSIS
		Writes log events using HTTP POST over the network
	.DESCRIPTION
		Adds a non-durable sink that sends log events using HTTP POST over the network. A non-durable sink will lose data after a system or process restart.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER RequestUri
		The URI the request is sent to
	.PARAMETER BatchPostingLimit
		The maximum number of events to post in a single batch. Default value is 1000.
	.PARAMETER QueueLimit
		The maximum number of events stored in the queue in memory, waiting to be posted over the network. Default value is 100000. Explicit $null leaves the queue unbounded.
	.PARAMETER Period
		The time to wait between checking for event batches. Default value is 2 seconds.
	.PARAMETER Formatter
		The formatter rendering individual log events into text. Defaults to PoShLog.Sinks.Http.TextFormatters.NormalRenderedTextFormatter. TextFormatter is an alias.
	.PARAMETER BatchFormatter
		The formatter batching multiple log events into a payload that can be sent over the network. Default value is PoShLog.Sinks.Http.BatchFormatters.ArrayBatchFormatter.
	.PARAMETER RestrictedToMinimumLevel
		The minimum level for events passed through the sink. Default value is Verbose.
	.PARAMETER HttpClient
		A custom PoShLog.Sinks.Http.IHttpClient implementation. The default is the native ApiKeyHttpClient without authentication.
	.PARAMETER Configuration
		Dictionary passed once to HttpClient.Configure. The http:apiKey entry sets X-Api-Key.

	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> New-Logger | Add-SinkHttp -RequestUri 'https://requestbin.net/r/test' | Start-Logger
	#>

	[OutputType([Serilog.LoggerConfiguration])]
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,

		[Parameter(Mandatory = $true)]
		[string]$RequestUri,

		[Parameter(Mandatory = $false)]
		[int]$BatchPostingLimit = 1000,

		[Parameter(Mandatory = $false)]
		[Nullable[System.Int32]]$QueueLimit = 100000,

		[Parameter(Mandatory = $false)]
		[Nullable[System.TimeSpan]]$Period = $null,

		[Parameter(Mandatory = $false)]
		[Alias('TextFormatter')]
		[Serilog.Formatting.ITextFormatter]$Formatter = $null,

		[Parameter(Mandatory = $false)]
		[PoShLog.Sinks.Http.IBatchFormatter]$BatchFormatter = $null,

		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,

		[Parameter(Mandatory = $false)]
		[PoShLog.Sinks.Http.IHttpClient]$HttpClient = $null,

		[Parameter(Mandatory = $false)]
		[System.Collections.IDictionary]$Configuration = $null
	)

	process {
		$LoggerConfig = [PoShLog.Sinks.Http.Compatibility.CountLimitedHttpSink]::Configure($LoggerConfig,
			$RequestUri,
			$BatchPostingLimit,
			$QueueLimit,
			$Period,
			$Formatter,
			$BatchFormatter,
			$RestrictedToMinimumLevel,
			$HttpClient,
			$Configuration
		)

		$LoggerConfig
	}
}
