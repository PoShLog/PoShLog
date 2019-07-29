function Write-WarningLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Warning($Text)
}