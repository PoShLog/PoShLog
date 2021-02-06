Import-Module PoShLog
Import-Module PoShLog.Enrichers

# Level switch allows you to switch minimum logging level at runtime
$levelSwitch = New-LevelSwitch -MinimumLevel Verbose

$l0 = New-Logger |
	Set-MinimumLevel -Value Verbose -ToPreference |
	Add-EnrichWithEnvironment |
	Add-EnrichWithExceptionDetails |
	Add-EnrichFromLogContext |
	Add-SinkPowerShell |
	Add-SinkConsole -OutputTemplate "[{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" | 
	Start-Logger -PassThru -SetAsDefault

Write-InfoLog -MessageTemplate 'Some default log'

Close-Logger -Logger $l0

# Setup new logger
$logger1 = New-Logger |
	Set-MinimumLevel -Value Verbose |
	Add-EnrichWithEnvironment |
	Add-EnrichWithExceptionDetails |
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' |
	Add-SinkConsole -OutputTemplate "[{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" | 
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
	Write-FatalLog -ErrorRecord $_ -MessageTemplate 'Error while reading file!'
}

Close-Logger