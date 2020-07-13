function Add-EnrichWithProperty {
	<#
	.SYNOPSIS
		Enriches log events with custom property.
	.DESCRIPTION
		Enriches log events with custom property. For example script name.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER Name
		The name of the property
	.PARAMETER Value
		The value of the property
	.PARAMETER DestructureObjects
		If true, and the value is a non-primitive, non-array type, then the value will be converted to a structure; otherwise, unknown types will be converted to scalars, which are generally stored as strings.
	.INPUTS
		None
	.OUTPUTS
		LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> New-Logger | Add-EnrichWithProperty -Name ScriptName -Value 'Test' | Add-SinkConsole | Start-Logger
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[string]$Value,
		[Parameter(Mandatory = $false)]
		[bool]$DestructureObjects = $false
	)

	process {
		$LoggerConfig = $LoggerConfig.Enrich.WithProperty($Name, $Value, $DestructureObjects)

		$LoggerConfig
	}
}