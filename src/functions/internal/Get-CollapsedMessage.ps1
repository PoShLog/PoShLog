function Get-CollapsedMessage{
	param(
		[parameter(Mandatory = $true)]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[object[]]$PropertyValues
	)

	if($null -eq $PropertyValues){
		$MessageTemplate
	}
	else{
		$index = 0
		$messageCollapsed = "";
		$MessageTemplate -split '\{.+?\}' | ForEach-Object { 
			$messageCollapsed += $_ + $PropertyValues[$index++]
		}

		$messageCollapsed
	}
}