# Set-MinimumLevel

Sets current minimum level of logger configuration.

```ps1
Set-MinimumLevel
    -LoggerConfig <LoggerConfiguration>
    -Value <LogEventLevel>
    [-ToPreference]
    [<CommonParameters>]
```

```ps1
Set-MinimumLevel
    -LoggerConfig <LoggerConfiguration>
    -ControlledBy <LoggingLevelSwitch>
    [<CommonParameters>]
```

```ps1
Set-MinimumLevel
    -LoggerConfig <LoggerConfiguration>
    -FromPreference
    [<CommonParameters>]
```

## Description

Sets the current minimum level of the logger configuration, below which no events should be generated.

> Implemented as the compiled `SetMinimumLevelCommand` cmdlet class (`src/dotnet/Cmdlets/LevelSwitch/SetMinimumLevelCommand.cs`), preserving the three original parameter sets.

## Examples

##### Example 1: Set logger minimum log level to `Warning`

```ps1
New-Logger |
    Set-MinimumLevel -Value Warning |
    Add-SinkConsole |
    Start-Logger
```

Now let's see what happens when we try to log event messages:

```ps1
Write-VerboseLog 'Verbose message that is not logged because logger minimum level'
Write-DebugLog 'Debug message that is not logged because logger minimum level'
Write-InfoLog 'Information message that is not logged because logger minimum level'
Write-WarningLog 'Warning message that gets logged'
```

Outputs:

```txt
[17:08:16 WRN] Warning message that gets logged
```

You can see that `Verbose`, `Debug`, and `Information` messages are not generated.

##### Example 2: Set logger minimum log level controlled by a level switch

Assume we created a level switch at minimum level `Verbose` using [`New-LevelSwitch`](New-LevelSwitch.md):

```ps1
$levelSwitch = New-LevelSwitch -MinimumLevel Verbose
```

We can now use `$levelSwitch` in the logger setup (see [New-Logger](New-Logger.md)):

```ps1
New-Logger |
    Set-MinimumLevel -ControlledBy $levelSwitch |
    Add-SinkFile -Path 'C:\Logs\test.log' |
    Add-SinkConsole |
    Start-Logger
```

Using `$levelSwitch`, you can change the current minimum logging level anywhere in following code. See also [New-LevelSwitch](New-LevelSwitch.md#examples).

##### Example 3: Set logger minimum log level to `Verbose` and propagate it to PowerShell preference variables

`-ToPreference` is especially useful when working with the PowerShell sink ([`Add-SinkPowerShell`](Add-SinkPowerShell.md)).

```ps1
New-Logger |
    Set-MinimumLevel -Value Verbose -ToPreference |
    Add-SinkPowerShell |
    Start-Logger

Write-VerboseLog 'Some verbose message in PowerShell verbose stream'
```

Outputs:

```txt
VERBOSE: Some verbose message in PowerShell verbose stream
```

## Parameters

##### `-LoggerConfig`

Instance of LoggerConfiguration.

|||
|-|-|
| Type: | LoggerConfiguration |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |

##### `-Value`

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
| Default value: |  |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-ControlledBy`

Instance of LoggingLevelSwitch. Used to change the logging level at runtime. Create one with [`New-LevelSwitch`](New-LevelSwitch.md).

|||
|-|-|
| Type: | LoggingLevelSwitch |
| Position: | Named |
| Default value: |  |
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

##### `-FromPreference`

Sets the minimum level according to the lowest [preference variable](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables). For example, if `$DebugPreference -eq 'Continue'` and `$VerbosePreference -eq 'SilentlyContinue'` then minimum level will be `Debug`.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
