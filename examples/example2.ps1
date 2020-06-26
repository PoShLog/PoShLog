# $VerbosePreference = 'SilentlyContinue'
# $DebugPreference = 'Continue'
# $InformationPreference = 'Continue'

Import-Module "$PSScriptRoot\..\src\PoShLog.psm1" -Force

New-Logger |
	Set-MinimumLevel -Value Verbose -ToPreference |
	Add-SinkFile -Path 'C:\Data\Log\test.log' |
	Add-SinkPowerShell  |
	Start-Logger

# Test all log levels
Write-VerboseLog 'Test verbose message'
'Test debug message' | Write-DebugLog
Write-DebugLog 'Test debug message {Num}' -PropertyValues 321
Write-DebugLog 'asd'
Write-DebugLog -MessageTemplate 'Write-DebugLogasd'
Write-InfoLog 'Test info message2'
Write-InformationLog 'Test info message2'
Write-WarningLog 'Test warning message'
Write-ErrorLog 'Test error message'
Write-FatalLog 'Test fatal message'

try {
    ConvertFrom-Json 'asd'
} catch {
	# Write-ErrorLog -MessageTemplate 'asd' -ErrorRecord $_
	# Write-ErrorLog 'asd {asd}' -ErrorRecord $_ -PropertyValues 321
	# 'Test debug message' | Write-ErrorLog -ErrorRecord $_
	Write-ErrorLog -ErrorRecord $_
}


# Example of formatted output
# $position = @{
#     Latitude = 25
#     Longitude = 134
# }
# $elapsedMs = 34

# Write-InfoLog 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs

Close-Logger