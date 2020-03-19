function Add-PackageTypes {
	process {
		try {
			# Load all package dlls
			Get-ChildItem $Global:packagesPath | Where-Object { $_.Name -like '*.dll' } | ForEach-Object { Add-Type -Path $_ -ErrorAction Stop }
		}
		catch {
			Write-Error ($_.Exception.GetBaseException().LoaderExceptions | Format-Table | Out-String)
		}
	}
}