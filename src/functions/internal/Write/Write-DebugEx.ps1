function Write-DebugEx{
	[CmdletBinding()]
	param(
		[parameter(Mandatory = $true, 
			ValueFromPipeline = $true)]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[object[]]$PropertyValues
	)

	Write-Debug -Message (Get-CollapsedMessage -MessageTemplate $MessageTemplate -PropertyValues $PropertyValues)
}