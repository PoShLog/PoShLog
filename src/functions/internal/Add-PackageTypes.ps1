function Add-PackageTypes {
	param(
		[Parameter(Mandatory = $true)]
		[string]$LibsDirectory
	)

	process {
		foreach ($path in (Get-ChildItem $LibsDirectory | Where-Object { $_.Name -like '*.dll' } | Select-Object -ExpandProperty FullName)) {
			Add-Type -Path $path
		}
	}
}