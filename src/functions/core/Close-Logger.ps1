function Close-Logger {
	<#
	.SYNOPSIS
		Resets Logger to the default and disposes the original if possible.
	.DESCRIPTION
		Resets Logger to the default and disposes the original if possible.
	.PARAMETER Logger
		Instance of Serilog.Logger. By default static property [Serilog.Log]::Logger is used.
	.INPUTS
		Instance of Serilog.Logger
	.OUTPUTS
		None
	.EXAMPLE
		PS> Close-Logger
	#>
	param(
		[Parameter(Mandatory = $false)]
		[Serilog.ILogger]$Logger
	)

	if($PSBoundParameters.ContainsKey('Logger')){
		$Logger.Dispose()
	}
	else{
		[Serilog.Log]::CloseAndFlush()
	}
}