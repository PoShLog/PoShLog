function Write-VerboseEx{
	[CmdletBinding()]
	param(
		[parameter(Mandatory = $true, 
			ValueFromPipeline = $true)]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[object[]]$PropertyValues
	)

	Write-Verbose -Message (Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues)
}