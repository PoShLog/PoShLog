function Write-WarningEx{
	[CmdletBinding()]
	param(
		[parameter(Mandatory = $true, 
			ValueFromPipeline = $true)]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[object[]]$PropertyValues
	)

	Write-Warning -Message (Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues)
}