function Set-MinimumLevel {
	<#
	.SYNOPSIS
		Sets current minimum level of logger configuration
	.DESCRIPTION
		Sets current minimum level of logger configuration, below which no events should be generated.
	.PARAMETER LoggerConfig
		Instance of LoggerConfiguration
	.PARAMETER Value
		The current minimum level, below which no events should be generated.
	.PARAMETER ControlledBy
		Sets the minimum level to be dynamically controlled by the provided switch
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		Instance of LoggerConfiguration object allowing method chaining with altered minumum logging level
	.EXAMPLE
		PS>  New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkConsole | Start-Logger
	.EXAMPLE
		PS> New-Logger | Set-MinimumLevel -ControlledBy $levelSwitch | Add-SinkConsole | Start-Logger
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $true, ParameterSetName = 'Level')]
		[Serilog.Events.LogEventLevel]$Value,
		[Parameter(Mandatory = $true, ParameterSetName = 'Switch')]
		[Serilog.Core.LoggingLevelSwitch]$ControlledBy
	)

	process {
		switch ($PsCmdlet.ParameterSetName) {
			'Level' {
				switch ($Value) {
					Verbose { $LoggerConfig.MinimumLevel.Verbose() }
					Debug { $LoggerConfig.MinimumLevel.Debug() }
					Information { $LoggerConfig.MinimumLevel.Information() }
					Warning { $LoggerConfig.MinimumLevel.Warning() }
					Error { $LoggerConfig.MinimumLevel.Error() }
					Fatal { $LoggerConfig.MinimumLevel.Fatal() }
					Default { $LoggerConfig.MinimumLevel.Information() }
				}
			}
			'Switch' {
				$LoggerConfig.MinimumLevel.ControlledBy($ControlledBy)
			}
		}
	}
}