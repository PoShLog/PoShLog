Import-Module "C:\Data\GIT\PoShLog\PoShLog.Core\src\PoShLog.psm1" -Force
Import-Module 'C:\Data\GIT\PoShLog\PoShLog.Core\publish\PoShLog.Enrichers'
Import-Module 'C:\Data\GIT\PoShLog\PoShLog.Core\publish\PoShLog.Sinks.Exceptionless'

# Get-Command Add-SinkFile -Syntax
# exit
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

# $DebugPreference = "Continue"
# $VerbosePreference = "Continue"

# Test default methods if Logger is not available
# Write-VerboseLog "test verbose"
# Write-DebugLog -MessageTemplate "test debug asd"
# Write-InfoLog -MessageTemplate  "test info {asd}, {num}" -PropertyValues "test1", 321
# Write-WarningLog "test warning"
# Write-ErrorLog -MessageTemplate "test error {asd}, {num}" -PropertyValues "test2", 123
# Write-FatalLog "test fatal"

$l0 = New-Logger |
	Set-MinimumLevel -Value Verbose -ToPreference |
	# Add-EnrichWithProperty -Name 'test' -Value 'aaa' |
	# Add-EnrichWithEnvironment |
	# Add-EnrichWithExceptionDetails |
	# Add-EnrichFromLogContext |
	Add-SinkPowerShell |
	Add-SinkConsole -OutputTemplate "[{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" | 
	Start-Logger -PassThru -SetAsDefault

# $LoggerConfig = New-Logger
# $LoggerConfig = [Serilog.SomeNamespace]::PSConsole($LoggerConfig.WriteTo)
# $LoggerConfig | Start-Logger

Write-InfoLog -MessageTemplate 'some default log'

Close-Logger -Logger $l0

$l0.Information("blballb")

# Setup new logger
$logger1 = New-Logger |
	Set-MinimumLevel -Value Verbose |
	Add-EnrichWithEnvironment |
	Add-EnrichWithExceptionDetails |
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' |
	# Add-SinkConsole -OutputTemplate "[{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" | 
	Add-SinkPowerShell |
	Start-Logger -PassThru

$logger2 = Start-Logger -FilePath "C:\Logs\test2-.txt" -Console -PassThru -MinimumLevel Verbose

# Write-VerboseLog "test verbose"
Write-DebugLog -MessageTemplate "test debug asd" -Logger $logger1

Set-Logger -Logger $logger2
Write-InfoLog -MessageTemplate $null
Write-InfoLog -MessageTemplate ''
Write-InfoLog -MessageTemplate 'asd {0} - {1}' -PropertyValues $null, '' -Exception $null


Write-DebugLog -MessageTemplate "test debug asdasdsad"

Write-WarningLog "test warning" -Logger $logger1

Set-Logger -Logger $logger1

Write-InfoLog "test info"

Write-ErrorLog -MessageTemplate "test error {asd}, {num}, {@levelSwitch}" -PropertyValues "test1", 123, $levelSwitch -Logger $logger2

try {
	Get-Content -Path 'asd' -ErrorAction Stop
}
catch {
	Write-FatalLog -Exception $_.Exception -MessageTemplate 'Error reading file!'
}

Close-Logger