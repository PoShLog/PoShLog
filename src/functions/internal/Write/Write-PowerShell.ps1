function Write-PowerShellSink {
	param(
		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEventLevel]$LogLevel,
		[parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[object[]]$PropertyValues,
		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[System.Exception]$Exception
	)

	if ($null -ne $global:PowerShellSink) {

		$message = Get-FormattedMessage -LogLevel $LogLevel -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues -Exception $Exception

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
				if($null -ne $Exception){
					Write-Error -Message $message -Exception $Exception
				}
				else{
					Write-Error -Message $message
				}
			}
			Default { 
				Write-Information -MessageData $message
			}
		}
	}
}