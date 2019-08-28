[string] $Global:packagesPath = "$env:APPDATA\PoShLog\packages"
[string] $Global:packagesConfigPath = "$PSScriptRoot\packages.config"

# dot source all script files
Get-ChildItem -Path "$PSScriptRoot\functions" -Recurse -File -Filter '*.ps1' | ForEach-Object {
	. $_.FullName

	# Export all functions except internal
	if ($_.FullName -notcontains 'internal') {
		Export-ModuleMember $_.BaseName
	}
}

# Restore packages.config into packages directory
Restore-AllExtensions

# Load all package dlls
Add-PackageTypes

