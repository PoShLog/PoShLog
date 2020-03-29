function New-Logger {
	<#
	.SYNOPSIS
		Creates new logger
	.DESCRIPTION
		Creates instance of serilog logger configuration
	.INPUTS
		None. You cannot pipe objects to New-Logger
	.OUTPUTS
		Instance of LoggerConfiguration object allowing method chaining
	.EXAMPLE
		PS> New-Logger
	#>

	try {
		# Just in case close and flush any previous logger
		Close-Logger
	}
	catch { }

	New-Object Serilog.LoggerConfiguration
}