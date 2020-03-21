function Write-HostEx {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[string]$MessageTemplate,
		[Parameter(Mandatory = $false)]
		[object[]]$PropertyValues,
		[parameter(Mandatory = $false)]
		[ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White,
		[parameter(Mandatory = $false)]
		[ConsoleColor]$HighlightColor = [System.ConsoleColor]::Yellow
	)

	if ($null -eq $PropertyValues) {
		Write-Host $MessageTemplate -ForegroundColor $ForegroundColor
	}
	else {
		$index = 0
		$MessageTemplate -split '\{.+?\}' | ForEach-Object { 
			Write-Host $_ -NoNewline -ForegroundColor $ForegroundColor
	
			Write-Host $PropertyValues[$index++] -NoNewline -ForegroundColor $HighlightColor
		}
		Write-Host
	}
}