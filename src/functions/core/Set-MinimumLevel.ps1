function Set-MinimumLevel{
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[Serilog.LoggerConfiguration]$loggerConfig,
		[Parameter(Mandatory=$true, ParameterSetName='Level')]
		[Serilog.Events.LogEventLevel]$MinimumLevel,
		[Parameter(Mandatory=$true, ParameterSetName='Switch')]
		[Serilog.Core.LoggingLevelSwitch]$ControlledBy
	)

	process{
		switch ($PsCmdlet.ParameterSetName){
			'Level'{
				switch ($MinimumLevel) {
					Verbose { $loggerConfig.MinimumLevel.Verbose() }
					Debug { $loggerConfig.MinimumLevel.Debug() }
					Information { $loggerConfig.MinimumLevel.Information() }
					Warning { $loggerConfig.MinimumLevel.Warning() }
					Error { $loggerConfig.MinimumLevel.Error() }
					Fatal { $loggerConfig.MinimumLevel.Fatal() }
					Default { $loggerConfig.MinimumLevel.Information() }
				}
			}
			'Switch'{
				$loggerConfig.MinimumLevel.ControlledBy($ControlledBy)
			}
		}
		
	}
}