Import-Module "$PSScriptRoot\..\PoShLog.psm1" -Force

# Start-Logger -Console

# Write-InfoLog 'Hurrray, my first log message'

# exit

# # Create and start new logger
# Start-Logger -MinimumLevel Verbose -FilePath 'C:\Data\my_awesome-.log' -FileRollingInterval Day

# Write-InfoLog 'Hurrray, my first log message'
# exit

# $position = @{ 
# 	Latitude = 25
# 	Longitude = 134 
# }
# $elapsedMs = 34

# Write-InfoLog 'Processed {@Position} in {Elapsed:000} ms.' -PropertyValues $position, $elapsedMs


# Close-Logger
# exit

# Level switch allows you to switch minimum logging level
$levelSwitch = New-LevelSwitch -MinimumLevel Verbose

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# Test default methods if Logger is not available
Write-VerboseLog "test verbose"
Write-DebugLog -MessageTemplate "test debug asd"
Write-InfoLog -MessageTemplate  "test info {asd}, {num}" -PropertyValues "test1", 321
Write-WarningLog "test warning"
Write-ErrorLog -MessageTemplate "test error {asd}, {num}" -PropertyValues "test2", 123
Write-FatalLog "test fatal"

# Setup new logger
New-Logger |
	Set-MinimumLevel -ControlledBy $levelSwitch |
	# Add-EnrichWithEnvironment |
	# Add-EnrichWithExceptionDetails |
	# Add-SinkExceptionless -ApiKey '' |
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' |
	Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose | 
	Start-Logger

Write-VerboseLog "test verbose"
Write-DebugLog -MessageTemplate "test debug asd"
Write-InfoLog "test info"
Write-WarningLog "test warning"
Write-ErrorLog -MessageTemplate "test error {asd}, {num}, {@levelSwitch}" -PropertyValues "test1", 123, $levelSwitch

try {
	Get-Content -Path 'asd' -ErrorAction Stop
}
catch {
	Write-FatalLog -Exception $_.Exception -MessageTemplate 'Error reading file!'
}

Close-Logger