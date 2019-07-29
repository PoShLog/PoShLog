function Write-InfoLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Information($Text)
}