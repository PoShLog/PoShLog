function Write-DebugLog {
	<#
	.SYNOPSIS
		Writes Debug log message
	.DESCRIPTION
		Write a log event with the Debug level.
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
		PS> Write-DebugLog 'Debug log message'
	.EXAMPLE
		PS> Write-DebugLog -MessageTemplate 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs
	.EXAMPLE
		PS> Write-DebugLog 'Error occured' -Exception ([System.Exception]::new('Some exception'))
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
				Write-DebugEx -MessageTemplate $MessageTemplate
			}
			else{
				[Serilog.Log]::Logger.Debug($MessageTemplate)
			}
		}
		'MessageTemplateWithProperties' {
			if (-not (Test-Logger)) {
				Write-DebugEx -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
			}
			else{
				[Serilog.Log]::Logger.Debug($MessageTemplate, $PropertyValues)
			}
		}
		'Exception' {
			if (-not (Test-Logger)) {
				Write-DebugEx -MessageTemplate "$MessageTemplate `n $Exception"
			}
			else{
				[Serilog.Log]::Logger.Debug($Exception, $MessageTemplate)
			}
		}
		'ExceptionWithProperties' {
			if (-not (Test-Logger)) {
				Write-DebugEx -MessageTemplate "$MessageTemplate `n $Exception" -PropertyValues $PropertyValues
			}
			else{
				[Serilog.Log]::Logger.Debug($Exception, $MessageTemplate, $PropertyValues)
			}
		}
	}

	if ($PassThru) {
		Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
	}
}
