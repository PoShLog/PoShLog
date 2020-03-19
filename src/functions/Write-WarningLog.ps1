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

			if(-not (Test-Logger)){
				Write-WarningEx -MessageTemplate $MessageTemplate
			}
		}
		'MessageTemplateWithProperties'{
			[Serilog.Log]::Logger.Warning($MessageTemplate, $PropertyValues)

			if(-not (Test-Logger)){
				Write-WarningEx -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
			}
		}
		'Excetion'{
			[Serilog.Log]::Logger.Warning($Exception, $MessageTemplate)

			if(-not (Test-Logger)){
				Write-WarningEx -MessageTemplate "$MessageTemplate `n $Exception"
			}
		}
		'ExcetionWithProperties'{
			[Serilog.Log]::Logger.Warning($Exception, $MessageTemplate, $PropertyValues)

			if(-not (Test-Logger)){
				Write-WarningEx -MessageTemplate "$MessageTemplate `n $Exception" -PropertyValues $PropertyValues
			}
		}
	}

	if($PassThru){
		Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
	}
}