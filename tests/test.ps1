Import-Module "$PSScriptRoot\..\PoShLog.psm1" -Force

# Install-PoShLogExtension -Id 'Serilog.Sinks.Exceptionless' -Version '3.1.0' -Silent
# Install-PoShLogExtension -Id 'Exceptionless' -Version '4.3.2027'

# Level switch allows you to switch minimum logging level
$levelSwitch = Get-LevelSwitch -MinimumLevel Verbose

New-Logger |
	Set-MinimumLevel -ControlledBy $levelSwitch |
	Add-EnrichWithEnvironment |
	Add-EnrichWithExceptionDetails |
	Add-SinkExceptionless -ApiKey "" |
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour -OutputTemplate '{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] {Message:lj}{NewLine}{Exception} {Properties:j}{NewLine}' |
	Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose | 
	Start-Logger

Write-VerboseLog "test verbose"
Write-DebugLog -MessageTemplate "test debug"
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