# $VerbosePreference = 'SilentlyContinue'
# $DebugPreference = 'Continue'
# $InformationPreference = 'Continue'

Import-Module "$PSScriptRoot\..\src\PoShLog.psm1" -Force

New-Logger |
	Set-MinimumLevel -Value Verbose -ToPreference |
	Add-EnrichWithErrorRecord |
	Add-EnrichFromLogContext |
	Add-SinkPowerShell -OutputTemplate '[{Timestamp:HH:mm:ss}] {Message:lj} {ErrorRecord}' |
	Start-Logger
	

# Test all log levels
Write-VerboseLog 'Test verbose message'
Write-DebugLog 'Test debug message'
Write-DebugLog 'Test debug message'
Write-InfoLog 'Test info message2'
Write-InformationLog 'Test info message2'
Write-WarningLog 'Test warning message'
Write-ErrorLog 'Test error message'
Write-FatalLog 'Test fatal message'

try {
    ConvertFrom-Json 'asd'
} catch {
    Write-ErrorLog 'Error occured' -ErrorRecord $_
}


# Example of formatted output
$position = @{
    Latitude = 25
    Longitude = 134
}
$elapsedMs = 34

Write-InfoLog 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs

Close-Logger