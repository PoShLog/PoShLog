# https://github.com/serilog/serilog-enrichers-environment
function Add-EnrichWithEnvironment{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig,
		[Parameter(Mandatory=$false)]
		[switch]$UserName,
		[Parameter(Mandatory=$false)]
		[switch]$MachineName
	)

	process{
		if($UserName -or ($UserName -eq $false -and $MachineName -eq $false)){
			$loggerConfig = [Serilog.EnvironmentLoggerConfigurationExtensions]::WithEnvironmentUserName($loggerConfig.Enrich)
		}
		if($MachineName){
			$loggerConfig = [Serilog.EnvironmentLoggerConfigurationExtensions]::WithMachineName($loggerConfig.Enrich)
		}

		$loggerConfig
	}
}