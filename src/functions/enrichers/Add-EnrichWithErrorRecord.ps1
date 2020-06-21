function Add-EnrichWithErrorRecord {
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$loggerConfig
	)

	process {
		$loggerConfig = [PoShLog.Core.Enrichers.Extensions.ErrorRecordEnricherExtensions]::WithErrorRecord($loggerConfig.Enrich)

		$loggerConfig
	}
}