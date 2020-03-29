function Write-WarningLog {
	<#
	.SYNOPSIS
		Writes Warning log message
	.DESCRIPTION
		Write a log event with the Warning level.
	.PARAMETER MessageTemplate
		Message template describing the event.
	.PARAMETER Exception
		Exception related to the event.
	.PARAMETER PropertyValues
		Objects positionally formatted into the message template.
	.PARAMETER PassThru
		Outputs MessageTemplate populated with PropertyValues into pipeline
	.INPUTS
		MessageTemplate - Message template describing the event.
	.OUTPUTS
		None or MessageTemplate populated with PropertyValues into pipeline if PassThru specified
	.EXAMPLE
		PS> Write-WarningLog 'Warning log message'
	.EXAMPLE
		PS> Write-WarningLog -MessageTemplate 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs
	.EXAMPLE
		PS> Write-WarningLog 'Error occured' -Exception ([System.Exception]::new('Some exception'))
	#>

	[Cmdletbinding(DefaultParameterSetName = 'MessageTemplate')]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'MessageTemplate')]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'MessageTemplateWithProperties')]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ExceptionWithProperties')]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $true, ParameterSetName = 'Exception')]
		[Parameter(Mandatory = $true, ParameterSetName = 'ExceptionWithProperties')]
		[System.Exception]$Exception,
		[Parameter(Mandatory = $true, ParameterSetName = 'ExceptionWithProperties')]
		[Parameter(Mandatory = $true, ParameterSetName = 'MessageTemplateWithProperties')]
		[object[]]$PropertyValues,
		[Parameter(Mandatory = $false)]
		[switch]$PassThru
	)

	switch ($PsCmdlet.ParameterSetName) {
		'MessageTemplate' {
			if (-not (Test-Logger)) {
				Write-WarningEx -MessageTemplate $MessageTemplate
			}
			else{
				[Serilog.Log]::Logger.Warning($MessageTemplate)
			}
		}
		'MessageTemplateWithProperties' {
			if (-not (Test-Logger)) {
				Write-WarningEx -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
			}
			else{
				[Serilog.Log]::Logger.Warning($MessageTemplate, $PropertyValues)
			}
		}
		'Exception' {
			if (-not (Test-Logger)) {
				Write-WarningEx -MessageTemplate "$MessageTemplate `n $Exception"
			}
			else{
				[Serilog.Log]::Logger.Warning($Exception, $MessageTemplate)
			}
		}
		'ExceptionWithProperties' {
			if (-not (Test-Logger)) {
				Write-WarningEx -MessageTemplate "$MessageTemplate `n $Exception" -PropertyValues $PropertyValues
			}
			else{
				[Serilog.Log]::Logger.Warning($Exception, $MessageTemplate, $PropertyValues)
			}
		}
	}

	if ($PassThru) {
		Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
	}
}