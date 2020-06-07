function Add-EnrichWithProperty{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory=$true)]
		[string]$Name,
		[Parameter(Mandatory=$true)]
		[string]$Value,
		[Parameter(Mandatory=$false)]
		[bool]$DestructureObjects = $false
	)

	process{
		$LoggerConfig = [Serilog.Configuration.LoggerEnrichmentConfiguration]::WithProperty($LoggerConfig.Enrich, $Name, $Value, $DestructureObjects)

		$LoggerConfig
	}
}