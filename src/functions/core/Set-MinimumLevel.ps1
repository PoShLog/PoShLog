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
	.PARAMETER ToPreference
		Set to propagate desired minimum level to preference variables. 
	.PARAMETER ControlledBy
		Sets the minimum level to be dynamically controlled by the provided switch
	.PARAMETER FromPreference
		Sets the minimum level according to the lowest preference variable. For example if $DebugPreference -eq 'Continue' and $VerbosePreference -eq 'SilentlyContinue' then minimum level will be Debug.
	.INPUTS
		Instance of LoggerConfiguration
	.OUTPUTS
		Instance of LoggerConfiguration object allowing method chaining with altered minumum logging level
	.EXAMPLE
		PS>  New-Logger | Set-MinimumLevel -Value Verbose | Add-SinkConsole | Start-Logger
	.EXAMPLE
		PS>  New-Logger | Set-MinimumLevel -Value Verbose -ToPreference | Add-SinkConsole | Start-Logger
	.EXAMPLE
		PS> New-Logger | Set-MinimumLevel -ControlledBy $levelSwitch | Add-SinkConsole | Start-Logger
	.EXAMPLE
		PS> New-Logger | Set-MinimumLevel -FromPreference | Add-SinkConsole | Start-Logger
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Serilog.LoggerConfiguration]$LoggerConfig,
		[Parameter(Mandatory = $true, ParameterSetName = 'Level')]
		[Serilog.Events.LogEventLevel]$Value,
		[Parameter(Mandatory = $false, ParameterSetName = 'Level')]
		[switch]$ToPreference,
		[Parameter(Mandatory = $true, ParameterSetName = 'Switch')]
		[Serilog.Core.LoggingLevelSwitch]$ControlledBy,
		[Parameter(Mandatory = $true, ParameterSetName = 'Preference')]
		[switch]$FromPreference
	)

	process {
		switch ($PsCmdlet.ParameterSetName) {
			'Level' {
				switch ($Value) {
					Verbose { 
						$LoggerConfig.MinimumLevel.Verbose()
					}
					Debug { 
						$LoggerConfig.MinimumLevel.Debug()
					}
					Information { 
						$LoggerConfig.MinimumLevel.Information()
					}
					Warning { 
						$LoggerConfig.MinimumLevel.Warning()
					}
					Error { $LoggerConfig.MinimumLevel.Error() }
					Fatal { $LoggerConfig.MinimumLevel.Fatal() }
					Default { $LoggerConfig.MinimumLevel.Information() }
				}

				if($ToPreference){
					Set-LogLevelToPreference -LogLevel $Value
				}
			}
			'Switch' {
				$LoggerConfig.MinimumLevel.ControlledBy($ControlledBy)
			}
			'Preference' {
				if ($VerbosePreference -eq 'Continue') {
					$LoggerConfig | Set-MinimumLevel -Value Verbose
				}
				elseif ($DebugPreference -eq 'Continue') {
					$LoggerConfig | Set-MinimumLevel -Value Debug
				}
				elseif ($InformationPreference -eq 'Continue') {
					$LoggerConfig | Set-MinimumLevel -Value Information
				}
				elseif ($WarningPreference -eq 'Continue') {
					$LoggerConfig | Set-MinimumLevel -Value Warning
				}
				else { 
					$LoggerConfig | Set-MinimumLevel -Value Error
				}
			}
		}
	}
}