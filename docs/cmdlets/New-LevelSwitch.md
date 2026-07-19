# New-LevelSwitch

Creates instance of LoggingLevelSwitch that dynamically controls logging level.

```ps1
New-LevelSwitch
    [[-MinimumLevel] <LogEventLevel>]
    [-ToPreference]
    [<CommonParameters>]
```

## Description

Creates a logging level switch that can dynamically control the minimum logging level, below which no events should be generated.

> Implemented as the compiled `NewLevelSwitchCommand` cmdlet class (`src/dotnet/Cmdlets/LevelSwitch/NewLevelSwitchCommand.cs`).

## Examples

##### Example 1: Level switch with initial `Verbose` logging level

```ps1
$levelSwitch = New-LevelSwitch -MinimumLevel Verbose
```

This level switch variable is then used during logger setup:

```ps1
New-Logger |
    Set-MinimumLevel -ControlledBy $levelSwitch |
    Add-SinkFile -Path 'C:\Logs\test.log' |
    Add-SinkConsole |
    Start-Logger
```

Using this `$levelSwitch` variable, you can change the current minimum logging level anywhere in your code.

```ps1
Write-VerboseLog 'Verbose message that gets logged'

Set-LevelSwitch $levelSwitch -MinimumLevel Debug

Write-VerboseLog 'Verbose message that is not logged because of changed level switch minimum level'
Write-DebugLog 'Debug message that gets logged'
```

Outputs:

```txt
[17:08:15 VRB] Verbose message that gets logged
[17:08:15 DBG] Debug message that gets logged
```

## Parameters

##### `-MinimumLevel`

Sets current minimum level, below which no events should be generated.

|||
|-|-|
| Type: | LogEventLevel |
| Position: | Named |
| Default value: | Information |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-ToPreference`

Set to propagate the desired minimum level to PowerShell [preference variables](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables).

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
