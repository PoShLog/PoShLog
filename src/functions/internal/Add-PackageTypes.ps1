function Add-PackageTypes {
	process {
		try {
			foreach ($path in (Get-ChildItem $Global:packagesPath | Where-Object { $_.Name -like '*.dll' } | Select-Object -ExpandProperty FullName)){
				Add-Type -Path $path -ErrorAction Stop
			}
		}
		catch {
			Write-Error $_.Exception
		}
	}
}