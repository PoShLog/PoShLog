function Write-ErrorLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Error($Text)
}