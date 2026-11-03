function Add-SinkEventLog {
	<#
	.SYNOPSIS
		Writes log events to console host
	.DESCRIPTION
		Writes log events to console host
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER Source
		The source name by which the application is registered on the local computer.
	.PARAMETER LogName
		The name of the log the source's entries are written to. Possible values include Application, System, or a custom event log.
	.PARAMETER MachineName
		The name of the machine hosting the event log written to. The local machine by default.
	.PARAMETER ManageEventSource
		If true, check/create event source as required.  Defaults to false i.e. do not allow sink to manage event source creation.
	.PARAMETER OutputTemplate
		A message template describing the format used to write to the sink.
	.PARAMETER FormatProvider
		Supplies culture-specific formatting information, or null.
	.PARAMETER RestrictedToMinimumLevel
		The minimum level for events passed through the sink. Ignored when LevelSwitch is specified.
	.PARAMETER EventIdProvider
		Supplies event ids for emitted log events
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> Add-SinkEventLog -Source 'SampleScript' -ManageEventSource $true
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $true)]
		[string]$Source,
		[Parameter(Mandatory = $false)]
		[string]$LogName,
		[Parameter(Mandatory = $false)]
		[string]$MachineName = '.',
		[Parameter(Mandatory = $false)]
		[string]$ManageEventSource = $false,
		[Parameter(Mandatory = $false)]
		[string]$OutputTemplate = '{Message}{NewLine}{Exception}{ErrorRecord}',
		[Parameter(Mandatory = $false)]
		[System.IFormatProvider]$FormatProvider = $null,
		[Parameter(Mandatory = $false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose,
		[Parameter(Mandatory = $false)]
		[Serilog.Sinks.EventLog.IEventIdProvider]$EventIdProvider = $null
	)

	process {
		$LoggerConfig = [Serilog.LoggerConfigurationEventLogExtensions]::EventLog($LoggerConfig.WriteTo,
			$Source,
			$LogName,
			$MachineName,
			$ManageEventSource,
			$OutputTemplate,
			$FormatProvider,
			$RestrictedToMinimumLevel,
			$EventIdProvider
		)

		$LoggerConfig
	}
}
