function Add-EnrichWithErrorRecord {
	<#
	.SYNOPSIS
		Enriches log events with ErrorRecord property if available.
	.DESCRIPTION
		Enriches log events with ErrorRecord property if available. Use -ErrorRecord parameter on Write-*Log cmdlets to add ErrorRecord.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration that is already setup.
	.PARAMETER DestructureObjects
		If true, and the value is a non-primitive, non-array type, then the value will be converted to a structure; otherwise, unknown types will be converted to scalars, which are generally stored as strings.
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
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $false)]
		[bool]$DestructureObjects = $false
	)

	process {
		$LoggerConfig = [PoShLog.Core.Enrichers.Extensions.ErrorRecordEnricherExtensions]::WithErrorRecord($LoggerConfig.Enrich, $DestructureObjects)

		$LoggerConfig
	}
}