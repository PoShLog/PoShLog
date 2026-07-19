function Get-Logger {
	<#
	.SYNOPSIS
		Gets current logger
	.DESCRIPTION
		Gets the current logger stored in the static property [Serilog.Log]::Logger
	.INPUTS
		None. You cannot pipe objects to Get-Logger
	.OUTPUTS
		Instance of Serilog.ILogger currently configured as the global logger
	.EXAMPLE
		PS> Get-Logger
	#>

	[Serilog.Log]::Logger
}
