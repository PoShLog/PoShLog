function Write-SinkPowerShell {
	param(
		[Parameter(Mandatory = $true)]
		[Serilog.ILogger]$Logger,
		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEventLevel]$LogLevel,
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[AllowNull()]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[object[]]$PropertyValues,
		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[System.Exception]$Exception
	)

	$powerShellSink = $global:PowerShellSinks[$Logger]
	if ($null -ne $powerShellSink) {

		# Make sure log level is enabled and is higher than RestrictedToMinimumLevel
		if([int]($LogLevel) -ge [int]($powerShellSink.RestrictedToMinimumLevel) -and $Logger.IsEnabled($LogLevel)){
			
			$message = Get-FormattedMessage -PowerShellSink $powerShellSink -LogLevel $LogLevel -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues -Exception $Exception

			switch ($LogLevel) {
				Verbose { 
					Write-Verbose -Message $message
				}
				Debug { 
					Write-Debug -Message $message
				}
				Information { 
					Write-Information -MessageData $message
				}
				Warning { 
					Write-Warning -Message $message
				}
				{($_ -eq 'Error') -or ($_ -eq 'Fatal')} { 
					Write-Output -InputObject $message
				}
				Default { 
					Write-Information -MessageData $message
				}
			}
		}
	}
}