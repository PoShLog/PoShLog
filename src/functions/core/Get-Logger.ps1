function Get-Logger{
	<#
	.SYNOPSIS
		Gets current default logger
	.DESCRIPTION
		Gets current default logger from static property that is globally available
	.INPUTS
		None
	.OUTPUTS
		None
	.EXAMPLE
		PS> $logger = Get-Logger
	#>

	process{
		[Serilog.Log]::Logger
	}
}