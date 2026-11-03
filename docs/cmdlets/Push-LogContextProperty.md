# Push-LogContextProperty

Adds properties to every event logged within a scope.

```ps1
Push-LogContextProperty
    [-Name] <string>
    [-Value] <object>
    [-Destructure]
    [[-ScriptBlock] <scriptblock>]
    [<CommonParameters>]
```

```ps1
Push-LogContextProperty
    -Property <IDictionary>
    [-Destructure]
    [[-ScriptBlock] <scriptblock>]
    [<CommonParameters>]
```

## Description

Pushes one or more properties onto Serilog's ambient `LogContext`. Every event written while the properties are on the context carries them. The logger must enrich from the context, so add [`Add-EnrichFromLogContext`](Add-EnrichFromLogContext.md) to the configuration; without it the properties are silently ignored.

- **With `-ScriptBlock`** the properties apply while the block runs and are removed when it ends, also when it throws. The block runs in a child scope, like `& { }`, and its output is passed through.
- **Without `-ScriptBlock`** the cmdlet returns a bookmark (`IDisposable`). The properties stay until you call `Dispose()` on it. Do that in a `finally` block. The bookmark lasts for the rest of the script or function run that pushed it. At an interactive prompt, prefer `-ScriptBlock`, because each prompt line is a separate run.

Scopes nest. An inner property with the same name hides the outer one until the inner scope ends. Dispose bookmarks in the reverse order you pushed them; disposing one restores the context to what it was when that bookmark was pushed.

This is the cmdlet the v2 docs called `Push-LogContextProp` (issue #34). Design notes: [ADR 0006](../decisions/0006-push-logcontextproperty-scope.md).

> Implemented as the compiled `PushLogContextPropertyCommand` cmdlet class (`src/dotnet/Cmdlets/Enrichers/PushLogContextPropertyCommand.cs`).

## Examples

##### Example 1: Tag every event of one job run

```ps1
New-Logger |
    Add-EnrichFromLogContext |
    Add-SinkFile -Path 'C:\Logs\jobs.log' -Formatter (Get-CompactFormatter) |
    Start-Logger

Push-LogContextProperty -Name RunId -Value ([guid]::NewGuid()) -ScriptBlock {
    Write-InfoLog 'Job started'
    Invoke-MyJob
    Write-InfoLog 'Job finished'
}
```

##### Example 2: Several properties, with a bookmark

```ps1
$bookmark = Push-LogContextProperty -Property @{ Job = 'nightly'; Server = $env:COMPUTERNAME }
try {
    Write-InfoLog 'Backup started'
}
finally {
    $bookmark.Dispose()
}
```

##### Example 3: Keep an object's structure

```ps1
Push-LogContextProperty -Name Request -Value ([pscustomobject]@{ Id = 7; User = 'tom' }) -Destructure {
    Write-InfoLog 'Handling request'
}
```

Without `-Destructure` the object is logged as its string form (`@{Id=7; User=tom}`).

## Parameters

##### `-Name`

The property name.

|||
|-|-|
| Type: | String |
| Position: | 0 |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Value`

The property value. A value PowerShell wrapped in a `PSObject` (an `int` from the pipeline) is logged as the plain value.

|||
|-|-|
| Type: | Object |
| Position: | 1 |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Property`

A hashtable of names and values to push together.

|||
|-|-|
| Type: | IDictionary |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Destructure`

Log objects with their structure, as `{@Name}` would in a message template, instead of as their string form.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-ScriptBlock`

The code to run with the properties on the context. When it is omitted, the cmdlet returns the bookmark instead.

|||
|-|-|
| Type: | ScriptBlock |
| Position: | 2 |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

## Outputs

Without `-ScriptBlock`: `System.IDisposable`, the bookmark. With `-ScriptBlock`: whatever the block outputs.
