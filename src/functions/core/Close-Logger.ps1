function Close-Logger {
	<#
	.SYNOPSIS
		Resets Logger to the default and disposes the original if possible.
	.DESCRIPTION
		Resets Logger to the default and disposes the original if possible.
	.INPUTS
		None. You cannot pipe objects to Close-Logger
	.OUTPUTS
		None
	.EXAMPLE
		PS> Close-Logger
	#>

	[Serilog.Log]::CloseAndFlush()
}