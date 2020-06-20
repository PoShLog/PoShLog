# For backwards compatibility and also shortand for Write-InformationLog

function Write-InfoLog {
	<#
	.SYNOPSIS
		Writes Information log message
	.DESCRIPTION
		Write a log event with the Information level.
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
		PS> Write-InfoLog 'Info log message'
	.EXAMPLE
		PS> Write-InfoLog -MessageTemplate 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs
	.EXAMPLE
		PS> Write-InfoLog 'Error occured' -Exception ([System.Exception]::new('Some exception'))
	#>

	[Cmdletbinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
		[AllowEmptyString()]
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

	Write-InformationLog -MessageTemplate $MessageTemplate -Logger $Logger -Exception $Exception -ErrorRecord $ErrorRecord -PropertyValues $PropertyValues -PassThru:$PassThru
}