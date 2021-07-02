function Enable-SelfLog {
	param(
		[Parameter(Mandatory = $false)]
		[System.Action[string]]$MessageFunc
	)

	if ($null -eq $MessageFunc) {
		$MessageFunc = { param([string]$msg) Write-Warning $msg }
	}

	[Serilog.Debugging.SelfLog]::Enable($MessageFunc)
}