# $VerbosePreference = 'SilentlyContinue'
# $DebugPreference = 'Continue'
# $InformationPreference = 'Continue'

Import-Module "$PSScriptRoot\..\PoShLog.psm1" -Force
# Import-Module PoShLog.Enrichers

New-Logger |
	Set-MinimumLevel -Value Debug -ToPreference |
	# Add-EnrichWithExceptionDetails |
	# Add-EnrichWithEnvironment |
	Add-EnrichWithErrorRecord |
	Add-SinkPowerShell -OutputTemplate '[{Timestamp:HH:mm:ss}] {Message:lj} {ErrorRecord}' |
	# Add-SinkFile -OutputTemplate '{MachineName} {Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}' -Path "C:\Logs\poshlogtest.txt" |
    # Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss}] {Message:lj}{NewLine}{ErrorRecord}' |
	Start-Logger
	

# Test all log levels
Write-VerboseLog 'Test verbose message'
Write-DebugLog 'Test debug message'
Write-DebugLog ''
Write-DebugLog 'Test debug message {asd}' -PropertyValues 123
Write-InfoLog 'Test info message1'
Write-InformationLog 'Test info message2'
Write-WarningLog 'Test warning message'
Write-ErrorLog 'Test error message'
Write-FatalLog 'Test fatal message'

try {
    ConvertFrom-Json 'asd'
} catch {
    Write-ErrorLog 'Errorito' -ErrorRecord $_
}


# Example of formatted output
$position = @{
    Latitude = 25
    Longitude = 134
}
$elapsedMs = 34

Write-InfoLog 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs

Close-Logger