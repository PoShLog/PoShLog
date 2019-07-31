# PoShLog

**[Note that this ps module is still in early development stage]**

PoShLog is powershell logging module. It is wrapper of great C# logging library Serilog - https://serilog.net/

## Installation

* Clone this repository / Download this repo as zip and extract all files

## Usage

```ps1
Import-Module "*Path to directory from installation step*\PoShLog.psm1"

# Level switch allows you to switch minimum logging level
$levelSwitch = Get-LevelSwitch -MinimumLevel Verbose

New-Logger |
	Set-MinimumLevel -ControlledBy $levelSwitch |
	Add-EnrichWithEnvironment |
	Add-SinkFile -Path "C:\Logs\test-.txt" -RollingInterval Hour | 
	Add-SinkConsole -OutputTemplate "[{EnvironmentUserName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}" | 
	Start-Logger

Write-VerboseLog "test verbose"
Write-DebugLog "test debug"
Write-InfoLog "test info"
Write-WarningLog "test warning"
Write-ErrorLog "test error"
Write-FatalLog "test fatal"

Close-Logger

```

## Commands

`New-Logger` - Creates new instance of *[Serilog.LoggerConfiguration]*.

`Start-Logger` - Creates a logger using the configured sinks, enrichers and minimum level.

`Close-Logger` - Resets Logger to the default and disposes the original if possible.

### Skinks

Sinks are used to record log events to some external representation. More info [here](https://github.com/serilog/serilog/wiki/Configuration-Basics). All available sinks - https://github.com/serilog/serilog/wiki/Provided-Sinks

`Add-SinkConsole` - Adds logging sink to log into console host. More info [here](https://github.com/serilog/serilog-sinks-console)

`Add-SinkFile` - Adds logging sink to log into file. More info [here](https://github.com/serilog/serilog-sinks-file)

### Enrichment

Log events can be enriched with various properties. These can be added trough nuget package(`Install-PoShLogExtension`). 

`Add-EnrichWithEnvironment` - Adds `MachineName` and `EnvironmentUserName` variables which can be used in **OutputTemplate** e.g. `Add-SinkConsole -OutputTemplate "[{EnvironmentUserName}{MachineName} {Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}"`

