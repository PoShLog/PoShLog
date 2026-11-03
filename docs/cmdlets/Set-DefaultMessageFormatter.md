# Set-DefaultMessageFormatter

Sets the output template of the text that the Write cmdlets return with `-PassThru`.

```ps1
Set-DefaultMessageFormatter
    -Template <String>
    [<CommonParameters>]
```

## Description

`Write-InfoLog … -PassThru` and the other [write cmdlets](Write-cmdlets.md) return the rendered message as a string,
so a script can show it or reuse it. By default the text is only the message (`{Message:lj}`). With
`Set-DefaultMessageFormatter` the text follows any Serilog output template, for example with the level or a
timestamp. The setting applies to the whole session and does not change what the sinks write.

> Implemented as the compiled `SetDefaultMessageFormatterCommand` cmdlet class (`src/dotnet/Cmdlets/Helpers/SetDefaultMessageFormatterCommand.cs`).

## Examples

##### Example 1: Return the level with the message

```ps1
Set-DefaultMessageFormatter -Template '[{Level:u3}] {Message:lj}'

$text = Write-WarningLog 'Disk {Drive} is {Percent} % full' -PropertyValues 'C:', 91 -PassThru
$text
```

Example output:

```
[WRN] Disk C: is 91 % full
```

##### Example 2: Back to the default

```ps1
Set-DefaultMessageFormatter -Template '{Message:lj}'
```

## Parameters

##### `-Template`

A Serilog [output template](https://github.com/serilog/serilog/wiki/Formatting-Output), for example
`'{Timestamp:HH:mm:ss} [{Level:u3}] {Message:lj}'`.

|||
|-|-|
| Type: | String |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

## Outputs

None.
