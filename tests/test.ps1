Import-Module "$PSScriptRoot\..\PoShLog.psm1" -Force

# Install-PoShLogExtension -Id 'Serilog' -Version '2.8.0' -Silent
# Install-PoShLogExtension -Id 'Serilog.Sinks.SlackClient' -Version '1.0.6671'

$levelSwitch = Get-LevelSwitch -MinimumLevel Verbose

New-Logger |
	Set-MinimumLevel -ControlledBy $levelSwitch |
	Add-EnrichWithEnvironment |
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour | 
	Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" -RestrictedToMinimumLevel Verbose | 
	Start-Logger
# https://hooks.slack.com/services/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
Write-VerboseLog "test verbose"
Write-DebugLog "test debug"
Write-InfoLog "test info"
Write-WarningLog "test warning"
Write-ErrorLog "test error"
Write-FatalLog "test fatal"

Close-Logger