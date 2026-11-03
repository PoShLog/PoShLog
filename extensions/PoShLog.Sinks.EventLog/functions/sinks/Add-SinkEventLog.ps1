function Add-SinkEventLog {
	<#
	.SYNOPSIS
		Writes log events to the Windows Event Log
	.DESCRIPTION
		Writes log events to the Windows Event Log
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
		Source management supports WhatIf and Confirm. If declined, the unchanged configuration is returned without adding the sink.
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
		PS> New-Logger | Add-SinkEventLog -Source 'SampleScript' -ManageEventSource $true -WhatIf
	#>

	[Cmdletbinding(SupportsShouldProcess = $true)]
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
		[bool]$ManageEventSource = $false,
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
		if ($ManageEventSource -and !$PSCmdlet.ShouldProcess("$MachineName/$Source", 'Check or create Event Log source')) {
			$LoggerConfig
			return
		}
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
