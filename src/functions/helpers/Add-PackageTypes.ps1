function Add-PackageTypes {
	param(
		[Parameter(Mandatory = $true)]
		[string]$LibsDirectory
	)

	process {
		$exceptions = @()
		foreach ($path in (Get-ChildItem $LibsDirectory | Where-Object { $_.Name -like '*.dll' } | Select-Object -ExpandProperty FullName)) {
			try
			{
				Add-Type -Path $path
			}
			catch [System.Reflection.ReflectionTypeLoadException]
			{
				$ex = $_.Exception
				Write-Host $ex.Message -ForegroundColor Yellow
				Write-Host $ex.StackTrace -ForegroundColor DarkYellow

				if($null -ne $ex.LoaderExceptions) { 
					foreach($loaderEx in $ex.LoaderExceptions) { 
						Write-Host "LoaderException: $loaderEx" -ForegroundColor Cyan
					}
				}

				$exceptions += $ex
			}
		}

		if($exceptions.Length -gt 0){
			throw (New-Object -TypeName System.AggregateException -ArgumentList $exceptions)
		}
	}
}