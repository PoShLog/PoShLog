function Write-ErrorLog {
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
			[Serilog.Log]::Logger.Error($MessageTemplate)

			if(-not (Test-Logger)){
				Write-Error -Message $MessageTemplate
			}
		}
		'MessageTemplateWithProperties'{
			[Serilog.Log]::Logger.Error($MessageTemplate, $PropertyValues)

			if(-not (Test-Logger)){
				Write-Error -Message (Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues)
			}
		}
		'Excetion'{
			[Serilog.Log]::Logger.Error($Exception, $MessageTemplate)

			if(-not (Test-Logger)){
				Write-Error -Exception $Exception -Message $MessageTemplate
			}
		}
		'ExcetionWithProperties'{
			[Serilog.Log]::Logger.Error($Exception, $MessageTemplate, $PropertyValues)

			if(-not (Test-Logger)){
				Write-Error -Exception $Exception -Message (Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues)
			}
		}
	}

	if($PassThru){
		Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
	}
}