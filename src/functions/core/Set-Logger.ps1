function Set-Logger {
	<#
	.SYNOPSIS
		Sets current logger
	.DESCRIPTION
		Sets given logger as static property that is globally available
	.PARAMETER Logger
		Instance of Serilog.Logger that will be available as static property
	.INPUTS
		Instance of Serilog.Logger
	.OUTPUTS
		None
	.EXAMPLE
		PS> Set-Logger -Logger $logger
	.EXAMPLE
		PS> $logger | Set-Logger
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.ILogger]$Logger
	)

	[Serilog.Log]::Logger = $Logger
}