function Write-ErrorLog {
	<#
	.SYNOPSIS
		Writes Error log message
	.DESCRIPTION
		Write a log event with the Error level.
	.PARAMETER MessageTemplate
		Message template describing the event.
	.PARAMETER Logger
		Instance of Serilog.Logger. By default static property [Serilog.Log]::Logger is used.
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
		PS> Write-ErrorLog 'Error log message'
	.EXAMPLE
		PS> Write-ErrorLog -MessageTemplate 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs
	.EXAMPLE
		PS> Write-ErrorLog 'Error occured' -Exception ([System.Exception]::new('Some exception'))
	#>

	[Cmdletbinding(DefaultParameterSetName = 'MessageTemplate')]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'MessageTemplate')]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'MessageTemplateWithProperties')]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'ExceptionWithProperties')]
		[AllowEmptyString()]
		[string]$MessageTemplate,

		[Parameter(Mandatory = $false)]
		[Serilog.ILogger]$Logger = [Serilog.Log]::Logger,

		[Parameter(Mandatory = $true, ParameterSetName = 'Exception')]
		[Parameter(Mandatory = $true, ParameterSetName = 'ExceptionWithProperties')]
		[AllowNull()]
		[System.Exception]$Exception,

		[Parameter(Mandatory = $true, ParameterSetName = 'ExceptionWithProperties')]
		[Parameter(Mandatory = $true, ParameterSetName = 'MessageTemplateWithProperties')]
		[AllowNull()]
		[object[]]$PropertyValues,

		[Parameter(Mandatory = $false)]
		[switch]$PassThru
	)

	switch ($PsCmdlet.ParameterSetName) {
		'MessageTemplate' {
			if (-not (Test-Logger $Logger)) {
				Write-Error -Message $MessageTemplate
			}
			else{
				$Logger.Error($MessageTemplate)
			}
		}
		'MessageTemplateWithProperties' {
			if (-not (Test-Logger $Logger)) {
				Write-Error -Message (Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues)
			}
			else{
				$Logger.Error($MessageTemplate, $PropertyValues)
			}
		}
		'Exception' {
			if (-not (Test-Logger $Logger)) {
				Write-Error -Exception $Exception -Message $MessageTemplate
			}
			else{
				$Logger.Error($Exception, $MessageTemplate)
			}
		}
		'ExceptionWithProperties' {
			if (-not (Test-Logger $Logger)) {
				Write-Error -Exception $Exception -Message (Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues)
			}
			else{
				$Logger.Error($Exception, $MessageTemplate, $PropertyValues)
			}
		}
	}

	if ($PassThru) {
		Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues
	}
}