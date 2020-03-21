function Write-VerboseLog {
	<#
	.SYNOPSIS
		Writes Verbose log message
	.DESCRIPTION
		Write a log event with the Verbose level.
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
		PS> Write-VerboseLog 'Verbose log message'
	.EXAMPLE
		PS> Write-VerboseLog -MessageTemplate 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs
	.EXAMPLE
		PS> Write-VerboseLog 'Error occured' -Exception ([System.Exception]::new('Some exception'))
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
			[Serilog.Log]::Logger.Verbose($MessageTemplate)

			if (-not (Test-Logger)) {
				Write-VerboseEx -MessageTemplate $MessageTemplate
			}
		}
		'MessageTemplateWithProperties' {
			[Serilog.Log]::Logger.Verbose($MessageTemplate, $PropertyValues)

			if (-not (Test-Logger)) {
				Write-VerboseEx -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
			}
		}
		'Exception' {
			[Serilog.Log]::Logger.Verbose($Exception, $MessageTemplate)

			if (-not (Test-Logger)) {
				Write-VerboseEx -MessageTemplate "$MessageTemplate `n $Exception"
			}
		}
		'ExceptionWithProperties' {
			[Serilog.Log]::Logger.Verbose($Exception, $MessageTemplate, $PropertyValues)

			if (-not (Test-Logger)) {
				Write-VerboseEx -MessageTemplate "$MessageTemplate `n $Exception" -PropertyValues $PropertyValues
			}
		}
	}

	if ($PassThru) {
		Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
	}
}