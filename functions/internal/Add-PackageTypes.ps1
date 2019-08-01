function Add-PackageTypes {
	process {
		[xml]$xml = Get-Content $Global:packagesConfigPath
		$packages = $xml.SelectSingleNode("//packages")

		foreach ($package in $packages.ChildNodes) {
			$packageId = $package.Attributes | Where-Object { $_.Name -eq 'id' } | Select-Object -ExpandProperty Value
			$packageVersion = $package.Attributes | Where-Object { $_.Name -eq 'version' } | Select-Object -ExpandProperty Value

			$assemblies = Get-ChildItem "$($Global:packagesPath)\$packageId.$packageVersion\lib\*" | 
				Where-Object { $_.Name -match 'net\d+' } | 
				ForEach-Object { Get-ChildItem "$($_.FullName)\*.dll" } 

			try {
				# Load package dlls
				Add-Type -Path $assemblies -ErrorAction 'Stop'
			}
			catch {
				Write-Error ($_.Exception.GetBaseException().LoaderExceptions | Format-Table | Out-String)
			}
		}
	}
}