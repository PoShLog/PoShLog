function New-Logger{

	# Just in case close and flush any previous logger
	Close-Logger

	# Get all dll files from \packages directory
	$assemblies = Get-ChildItem "$($Global:packagesPath)\*\lib\*" | Where-Object { $_.Name -match 'net\d+' } | ForEach-Object { Get-ChildItem "$($_.FullName)\*.dll" } 

	Add-Type -Path $assemblies

	New-Object Serilog.LoggerConfiguration
}