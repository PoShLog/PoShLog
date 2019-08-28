# PoShLog

PoShLog is powershell logging module. It is wrapper of great C# logging library Serilog - https://serilog.net/

## Installation

```ps1
PS> Install-Module -Name PoShLog
```

## Usage

```ps1
Import-Module PoShLog

# Level switch allows you to switch minimum logging level
$levelSwitch = Get-LevelSwitch -MinimumLevel Verbose

New-Logger |
	Set-MinimumLevel -ControlledBy $levelSwitch |
	Add-EnrichWithEnvironment |
	Add-EnrichWithExceptionDetails |
	Add-SinkExceptionless -ApiKey "YOUR API KEY" |
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
```

**Code above results in:**

Console:
<img src="https://github.com/TomasBouda/PoShLog/blob/master/images/PoShLog_example.png">

File *(C:\Logs\test-2019080511.txt)*:
```log
2019-08-05 11:03:29.256 +02:00 [VRB] test verbose
 {"EnvironmentUserName":"DESKTOP-asd\\email"}
2019-08-05 11:03:29.443 +02:00 [DBG] test debug
 {"EnvironmentUserName":"DESKTOP-asd\\email"}
2019-08-05 11:03:29.450 +02:00 [INF] test info
 {"EnvironmentUserName":"DESKTOP-asd\\email"}
2019-08-05 11:03:29.456 +02:00 [WRN] test warning
 {"EnvironmentUserName":"DESKTOP-asd\\email"}
2019-08-05 11:03:29.470 +02:00 [ERR] test fatal test1, 123, {"MinimumLevel":"Verbose","$type":"LoggingLevelSwitch"}
 {"EnvironmentUserName":"DESKTOP-asd\\email"}
2019-08-05 11:03:29.573 +02:00 [FTL] Chyba
System.Exception: Some random exception
 {"EnvironmentUserName":"DESKTOP-asd\\email","ExceptionDetail":{"Type":"System.Exception","HResult":-2146233088,"Message":"Some random exception","Source":null}}
 ```
*(it also logs into [exceptionless.io](https://be.exceptionless.io))*

## Commands

`New-Logger` - Creates new instance of *[Serilog.LoggerConfiguration]*.

`Set-MinimumLevel` - Sets minimum log level which will be logged. More info [here](https://github.com/serilog/serilog/wiki/Writing-Log-Events)

`Start-Logger` - Creates a logger using the configured sinks, enrichers and minimum level.

`Close-Logger` - Resets Logger to the default and disposes the original if possible.

### Skinks

Sinks are used to record log events to some external representation. More info [here](https://github.com/serilog/serilog/wiki/Configuration-Basics). All available sinks - https://github.com/serilog/serilog/wiki/Provided-Sinks

`Add-SinkConsole` - Adds logging sink to log into console host. More info [here](https://github.com/serilog/serilog-sinks-console)

`Add-SinkFile` - Adds logging sink to log into file. More info [here](https://github.com/serilog/serilog-sinks-file)

`Add-SinkExceptionless` - Adds logging sink to log into exceptionless cloud. More info [here](https://github.com/serilog/serilog-sinks-exceptionless) and [here](https://exceptionless.com/)

### Enrichment

Log events can be enriched with various properties. These enrichers can be added trough nuget package(`Install-PoShLogExtension`). More info [here](https://github.com/serilog/serilog/wiki/Enrichment)

`Add-EnrichWithEnvironment` - Adds `{MachineName}` and `{EnvironmentUserName}` variables which can be used in **OutputTemplate** 
e.g. 
```
Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}"
```

`Add-EnrichWithProcessId` - Adds `{ProcessId}` variables which can be used in **OutputTemplate**

`Add-EnrichWithProcessName` - Adds `{ProcessName}` variables which can be used in **OutputTemplate**

`Add-EnrichWithExceptionDetails` - Adds exception details into log. Note that you must add {Properties:j} to **OutputTemplate**. More info [here](https://github.com/RehanSaeed/Serilog.Exceptions)
