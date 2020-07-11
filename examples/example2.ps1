Import-Module PoShLog

New-Logger |
	Set-MinimumLevel -Value Verbose -ToPreference |
	Add-EnrichWithErrorRecord |
	Add-SinkFile -Path 'C:\Logs\test.log' |
	Add-SinkPowerShell |
	Start-Logger

# Test all log levels
Write-VerboseLog 'Test verbose message'
'Test debug message usig pipeline' | Write-DebugLog
Write-DebugLog 'Test debug message {Num}' -PropertyValues 321
Write-DebugLog -MessageTemplate 'Write-DebugLog using MessageTemplate'
Write-InfoLog 'Test info message'
Write-InformationLog 'Test info message 2'
Write-WarningLog 'Test warning message'
Write-ErrorLog 'Test error message'
Write-FatalLog 'Test fatal message'

try {
    ConvertFrom-Json 'asd'
} catch {
	Write-ErrorLog 'Error while converting fron json!' -ErrorRecord $_
}

Close-Logger