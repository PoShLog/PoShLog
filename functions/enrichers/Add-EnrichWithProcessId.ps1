# https://github.com/serilog/serilog-enrichers-process
function Add-EnrichWithProcessId{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	process{
		$loggerConfig = [Serilog.ProcessLoggerConfigurationExtensions]::WithProcessId($loggerConfig.Enrich)

		$loggerConfig
	}
}