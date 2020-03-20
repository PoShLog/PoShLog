[string] $Global:packagesPath = "$PSScriptRoot\lib"
[string] $obsoletePackagesPath = "$env:APPDATA\PoShLog\packages"

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
if (Test-Path $obsoletePackagesPath ) {
	Remove-Item $obsoletePackagesPath -Recurse -Force -ErrorAction SilentlyContinue
}