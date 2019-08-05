function Write-WarningLog {
	[cmdletbinding(DefaultParameterSetName='MessageTemplate')]
	param(
		[Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'MessageTemplate')]
		[Parameter(Mandatory = $true, ParameterSetName = 'MessageTemplateWithProperties')]
		[Parameter(Mandatory = $true, ParameterSetName = 'Excetion')]
		[Parameter(Mandatory = $true, ParameterSetName = 'ExcetionWithProperties')]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $true, ParameterSetName = 'Excetion')]
		[Parameter(Mandatory = $true, ParameterSetName = 'ExcetionWithProperties')]
		[System.Exception]$Exception,
		[Parameter(Mandatory = $true, ParameterSetName = 'ExcetionWithProperties')]
		[Parameter(Mandatory = $true, ParameterSetName = 'MessageTemplateWithProperties')]
		[object[]]$PropertyValues,
		[Parameter(Mandatory = $false)]
		[switch]$PassThru
	)

	switch ($PsCmdlet.ParameterSetName){
		'MessageTemplate'{
			[Serilog.Log]::Logger.Warning($MessageTemplate)
		}
		'MessageTemplateWithProperties'{
			[Serilog.Log]::Logger.Warning($MessageTemplate, $PropertyValues)
		}
		'Excetion'{
			[Serilog.Log]::Logger.Warning($Exception, $MessageTemplate)
		}
		'ExcetionWithProperties'{
			[Serilog.Log]::Logger.Warning($Exception, $MessageTemplate, $PropertyValues)
		}
	}

	if($PassThru){
		$Text
	}
}