function Add-EnrichFromLogContext {
	<#
	.SYNOPSIS
		Enriches log events with properties from LogContext
	.DESCRIPTION
		Enriches log events with properties from LogContext. Use Push-LogContextProp to add properties.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration that is already setup.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		Instance of LoggerConfiguration
	.EXAMPLE
		PS> New-Logger | Add-EnrichFromLogContext | Add-SinkConsole | Start-Logger
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig
	)

	process {
		$LoggerConfig.Enrich.FromLogContext()
	}
}