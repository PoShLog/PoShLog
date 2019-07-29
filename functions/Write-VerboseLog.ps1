function Write-VerboseLog {
	param(
		[Parameter(Mandatory = $true)]
		[string]$Text
	)

	[Serilog.Log]::Logger.Verbose($Text)
}