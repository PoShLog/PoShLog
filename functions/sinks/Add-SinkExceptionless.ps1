function Add-SinkExceptionless{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig,
		[Parameter(Mandatory=$true)]
		[string]$ApiKey,
		[Parameter(Mandatory=$false)]
		[bool]$IncludeProperties = $true,
		[Parameter(Mandatory=$false)]
		[Serilog.Events.LogEventLevel]$RestrictedToMinimumLevel = [Serilog.Events.LogEventLevel]::Verbose
	)

	process{
		# $func = 
		# {  
		# 	$b = $args[0]
		# 	return $b
		# }
		
		$loggerConfig = [Serilog.LoggerSinkConfigurationExtensions]::Exceptionless($loggerConfig.WriteTo,
			$ApiKey,
			$null,
			$null,
			$IncludeProperties,
			$RestrictedToMinimumLevel
		)

		$loggerConfig
	}
}