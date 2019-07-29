Import-Module "$PSScriptRoot\..\PoShLog.psm1" -Force

# Restore-AllExtensions

# Install-PoShLogExtension -Id 'Serilog' -Version '2.8.0'
# Install-PoShLogExtension -Id 'Serilog.Enrichers.Process' -Version '2.0.1' -Restore

$levelSwitch = [Serilog.Core.LoggingLevelSwitch]::new()
$levelSwitch.MinimumLevel = [Serilog.Events.LogEventLevel]::Verbose

New-Logger |
	Set-MinimumLevel -ControlledBy $levelSwitch  |
	Add-EnrichWithEnvironment |
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour | 
	Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose | 
	Start-Logger

Write-VerboseLog "test verbose"
Write-DebugLog "test debug"
Write-InfoLog "test info"
Write-WarningLog "test warning"
Write-ErrorLog "test error"
Write-FatalLog "test fatal"

Close-Logger