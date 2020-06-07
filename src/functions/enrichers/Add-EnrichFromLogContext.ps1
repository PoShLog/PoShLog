function Add-EnrichFromLogContext{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	process{
		$loggerConfig = [Serilog.Configuration.LoggerEnrichmentConfiguration]::FromLogContext($loggerConfig.Enrich)

		$loggerConfig
	}
}