Import-Module "$PSScriptRoot\..\PoShLog.psm1" -Force

# Level switch allows you to switch minimum logging level
$levelSwitch = Get-LevelSwitch -MinimumLevel Verbose

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
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' |
	Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose | 
	Start-Logger

Write-VerboseLog "test verbose"
Write-DebugLog -MessageTemplate "test debug asd"
Write-InfoLog "test info"
Write-WarningLog "test warning"
Write-ErrorLog -MessageTemplate "test fatal {asd}, {num}, {@levelSwitch}" -PropertyValues "test1", 123, $levelSwitch

try {
	throw [System.Exception]::new('Some random exception')
}
catch {
	Write-FatalLog -Exception $_.Exception -MessageTemplate 'Chyba'
}

Close-Logger