function Restore-AllExtensions{

	# Clean packages directory
	Remove-Item "$Global:packagesPath\*" -Recurse -Force

	# Nuget restore
	& "$PSScriptRoot\..\..\tools\Nuget-Restore.ps1"
}
