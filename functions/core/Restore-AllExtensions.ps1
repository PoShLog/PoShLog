function Restore-AllExtensions {
	param(
		[Parameter(Mandatory = $false)]
		[switch]$Silent
	)

	# Install NuGet if not available
	if((Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq 'NuGet' } | Measure-Object).Count -eq 0){
		if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
			Start-Process powershell -Verb runAs -ArgumentList 'Install-PackageProvider -Name "NuGet" -Confirm:$false -Force -Verbose'
		}
	}

	# Restore nuget packages from packages.config
	nuget install "$PSScriptRoot\..\..\packages.config" -ConfigFile "$PSScriptRoot\..\..\NuGet.config" -OutputDirectory $Global:packagesPath | Where-Object { -not $Silent } | Write-Host
}
