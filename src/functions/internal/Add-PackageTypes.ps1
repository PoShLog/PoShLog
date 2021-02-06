function Add-PackageTypes {
	param(
		[Parameter(Mandatory = $true)]
		[string]$LibsDirectory
	)

	process {
		foreach ($path in (Get-ChildItem $LibsDirectory | Where-Object { $_.Name -like '*.dll' } | Select-Object -ExpandProperty FullName)) {
			try
			{
				Add-Type -Path $path
			}
			catch [System.Reflection.ReflectionTypeLoadException]
			{
				Write-Host $_.Exception.Message -ForegroundColor Yellow
				Write-Host $_.Exception.StackTrace -ForegroundColor DarkYellow

				if($null -ne $_.Exception.LoaderExceptions) { 
					foreach($loaderEx in $_.Exception.LoaderExceptions) { 
						Write-Host "LoaderException: $loaderEx" -ForegroundColor Cyan
					}
				}

				# throw 'Error occured while loading PoShLog libraries!'
			}
		}
	}
}