# https://github.com/serilog/serilog-enrichers-process
function Add-EnrichWithProcessName{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	process{
		$loggerConfig = [Serilog.ProcessLoggerConfigurationExtensions]::WithProcessName($loggerConfig.Enrich)

		$loggerConfig
	}
}