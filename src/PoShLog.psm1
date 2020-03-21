[string] $Global:packagesPath = "$PSScriptRoot\lib"
[bool] $Global:loggerNotInitWarned = $false	# Indicates wether warning about logger is not initialized was shown

# dot source all script files
Get-ChildItem -Path "$PSScriptRoot\functions" -Recurse -File -Filter '*.ps1' | ForEach-Object {
	. $_.FullName

	# Export all functions except internal
	if ($_.FullName -notcontains 'internal') {
		Export-ModuleMember $_.BaseName
	}
}

# Load all package dlls
Add-PackageTypes

# Remove package directory from previous version
[string] $obsoletePackagesPath = "$env:APPDATA\PoShLog\packages"
if (Test-Path $obsoletePackagesPath ) {
	Remove-Item $obsoletePackagesPath -Recurse -Force -ErrorAction SilentlyContinue
}