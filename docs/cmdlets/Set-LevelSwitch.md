# Set-LevelSwitch

Sets minimum level of a given level switch.

```ps1
Set-LevelSwitch
    [-LevelSwitch] <LoggingLevelSwitch>
    [-MinimumLevel] <LogEventLevel>
    [-ToPreference]
    [-PassThru]
    [<CommonParameters>]
```

## Description

Used to change the minimum logging level of a given switch at runtime.

> Implemented as the compiled `SetLevelSwitchCommand` cmdlet class (`src/dotnet/Cmdlets/LevelSwitch/SetLevelSwitchCommand.cs`).

## Examples

Assume we created a level switch at minimum level `Verbose` using [`New-LevelSwitch`](New-LevelSwitch.md):

```ps1
$levelSwitch = New-LevelSwitch -MinimumLevel Verbose
```

and used `$levelSwitch` in logger setup (see [New-Logger](New-Logger.md) and [Set-MinimumLevel `-ControlledBy`](Set-MinimumLevel.md#-controlledby)):

```ps1
New-Logger |
    Set-MinimumLevel -ControlledBy $levelSwitch |
    Add-SinkConsole |
    Start-Logger
```

##### Example 1: Changing minimum log level to `Debug` at runtime

```ps1
Write-VerboseLog 'Verbose message that gets logged'
Write-DebugLog 'Debug message that gets logged'

Set-LevelSwitch $levelSwitch -MinimumLevel Debug

Write-VerboseLog 'Verbose message that is not logged because of changed level switch minimum level'
Write-DebugLog 'Debug message that gets logged'
```

Outputs:

```txt
[17:08:15 VRB] Verbose message that gets logged
[17:08:15 DBG] Debug message that gets logged
[17:08:16 DBG] Debug message that gets logged
```

You can see that after changing the minimum level to `Debug`, `Verbose` messages are no longer generated.

## Parameters

##### `-LevelSwitch`

Instance of LoggingLevelSwitch to change. Create one with [`New-LevelSwitch`](New-LevelSwitch.md).

|||
|-|-|
| Type: | LoggingLevelSwitch |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |

##### `-MinimumLevel`

Sets current minimum level, below which no events should be generated.

Following values are allowed:

* Verbose
* Debug
* Information
* Warning
* Error
* Fatal

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

##### `-PassThru`

Outputs the created instance of `Serilog.Core.LoggingLevelSwitch` into the pipeline.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
