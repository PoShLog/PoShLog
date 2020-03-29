function Test-Logger{
	$isInitialized = [Serilog.Log]::Logger.GetType() -eq [Serilog.Core.Logger]

	if(-not $isInitialized -and -not $Global:loggerNotInitWarned){
		Write-Warning 'PoShLog logger not initialized! Please setup new logger, e.g. by running Start-Logger. For more info see documentation.'
		$Global:loggerNotInitWarned = $true
	}

	$isInitialized
}