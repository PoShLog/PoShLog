[string] $Global:packagesPath = "$PSScriptRoot\lib"

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

