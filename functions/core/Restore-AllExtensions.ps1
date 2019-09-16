function Restore-AllExtensions {
	param(
		[Parameter(Mandatory = $false)]
		[switch]$Silent
	)

	$nugetPath = "$PSScriptRoot\..\..\tools\nuget.exe"

	# Install NuGet if not available
	if(-not (Test-Path $nugetPath)){
		Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetPath
	}

	# Restore nuget packages from packages.config
	& $nugetPath install "$PSScriptRoot\..\..\packages.config" -ConfigFile "$PSScriptRoot\..\..\NuGet.config" -OutputDirectory $Global:packagesPath | Where-Object { -not $Silent } | Write-Host
}
