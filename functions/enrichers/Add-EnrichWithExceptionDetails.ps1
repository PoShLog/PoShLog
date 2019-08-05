# https://github.com/serilog/serilog-enrichers-environment
function Add-EnrichWithExceptionDetails{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	process{
		$loggerConfig = [Serilog.Exceptions.LoggerEnrichmentConfigurationExtensions]::WithExceptionDetails($loggerConfig.Enrich)

		$loggerConfig
	}
}