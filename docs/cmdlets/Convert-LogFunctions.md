# Convert-LogFunctions

Converts default PowerShell `Write-*` cmdlets in a script file into PoShLog `Write-*Log` cmdlets.

```ps1
Convert-LogFunctions
    -FilePath <string>
    [<CommonParameters>]
```

## Description

A migration helper that rewrites a `.ps1` script file in place, replacing calls to the built-in `Write-Verbose`, `Write-Debug`, `Write-Information`, `Write-Host`, `Write-Warning`, and `Write-Error` cmdlets with their PoShLog `Write-*Log` equivalents:

| From | To |
|-|-|
| `Write-Verbose` | `Write-VerboseLog` |
| `Write-Debug` | `Write-DebugLog` |
| `Write-Information` / `Write-Host` | `Write-InfoLog` |
| `Write-Warning` | `Write-WarningLog` |
| `Write-Error` | `Write-ErrorLog` |

> Implemented as the compiled `ConvertLogFunctionsCommand` cmdlet class (`src/dotnet/Cmdlets/Helpers/ConvertLogFunctionsCommand.cs`). This is a text-replacement helper, not a full AST-based rewrite — review the result before committing.

## Examples

##### Example 1: Convert a script file to use PoShLog cmdlets

```ps1
Convert-LogFunctions -FilePath 'C:\Scripts\my-script.ps1'
```

Or via the pipeline:

```ps1
Get-ChildItem 'C:\Scripts\*.ps1' | ForEach-Object FullName | Convert-LogFunctions
```

## Parameters

##### `-FilePath`

Path to the `.ps1` file to convert.

|||
|-|-|
| Type: | string |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | True (ByValue) |
| Accept wildcard characters: | False |
