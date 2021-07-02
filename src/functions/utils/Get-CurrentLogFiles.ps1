function Get-CurrentLogFiles {
	<#
	.SYNOPSIS
		Returns collection of current log files
	.DESCRIPTION
		Returns collection of current log files or null if no log files are used.
		Usefull when using rolling log file e.g. Add-SinkFile -Path 'D:\test-.log' -RollingInterval Day.
	.PARAMETER Logger
		Instance of Serilog.Logger. By default static property [Serilog.Log]::Logger is used.
	.INPUTS
		Instance of Serilog.Logger
	.OUTPUTS
		String array
	.EXAMPLE
		PS> Get-Logger | Get-CurrentLogFiles
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $false, ValueFromPipeline = $true)]
		[Serilog.ILogger]$Logger
	)

	process{
		if($null -eq $Logger){
			$Logger = [Serilog.Log]::Logger
		}

		[PoShLog.Core.Extensions.LoggerExtensions]::GetCurrentLogFiles($Logger)
	}
}