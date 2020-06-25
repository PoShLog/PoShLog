function Write-Log {
	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true)]
		[Serilog.Events.LogEventLevel]$LogLevel,

		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[AllowNull()]
		[string]$MessageTemplate,

		[Parameter(Mandatory = $false)]
		[Serilog.ILogger]$Logger = [Serilog.Log]::Logger,

		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[System.Exception]$Exception,

		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[System.Management.Automation.ErrorRecord]$ErrorRecord,

		[Parameter(Mandatory = $false)]
		[AllowNull()]
		[object[]]$PropertyValues,

		[Parameter(Mandatory = $false)]
		[switch]$PassThru
	)

	# If ErrorRecord is available wrap it into RuntimeException
	if($null -ne $ErrorRecord){

		if($null -eq $Exception){
			$Exception = $ErrorRecord.Exception
		}

		$Exception = [PoShLog.Core.Exceptions.WrapperException]::new($Exception, $ErrorRecord)
	}

	switch ($LogLevel) {
		Verbose { 
			$Logger.Verbose($Exception, $MessageTemplate, $PropertyValues)
		}
		Debug { 
			$Logger.Debug($Exception, $MessageTemplate, $PropertyValues)
		}
		Information { 
			$Logger.Information($Exception, $MessageTemplate, $PropertyValues)
		}
		Warning { 
			$Logger.Warning($Exception, $MessageTemplate, $PropertyValues)
		}
		Error { 
			$Logger.Error($Exception, $MessageTemplate, $PropertyValues)
		}
		Fatal { 
			$Logger.Fatal($Exception, $MessageTemplate, $PropertyValues)
		}
	}

	if ($PassThru) {
		Get-FormattedMessage -Logger $Logger -LogLevel $LogLevel -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues -Exception $Exception
	}
}