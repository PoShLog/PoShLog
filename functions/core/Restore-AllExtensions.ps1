function Restore-AllExtensions {
	param(
		[Parameter(Mandatory = $false)]
		[switch]$Silent
	)

	# Restore nuget packages from packages.config
	nuget install "$PSScriptRoot\..\..\packages.config" -ConfigFile "$PSScriptRoot\..\..\NuGet.config" -OutputDirectory "$PSScriptRoot\..\..\packages" | ? { -not $Silent } | Write-Host
}
