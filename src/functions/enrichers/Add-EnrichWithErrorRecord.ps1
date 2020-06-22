function Add-EnrichWithErrorRecord {
	<#
	.SYNOPSIS
		Enriches log events with ErrorRecord property if available.
	.DESCRIPTION
		Enriches log events with ErrorRecord property if available. Use -ErrorRecord parameter on Write-*Log cmdlets to add ErrorRecord.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration that is already setup.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		Instance of LoggerConfiguration
	.EXAMPLE
		PS> New-Logger | Add-EnrichWithErrorRecord | Add-SinkPowerShell | Start-Logger
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig
	)

	process {
		$LoggerConfig = [PoShLog.Core.Enrichers.Extensions.ErrorRecordEnricherExtensions]::WithErrorRecord($LoggerConfig.Enrich)

		$LoggerConfig
	}
}