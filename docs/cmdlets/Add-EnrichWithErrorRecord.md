# Add-EnrichWithErrorRecord

Enriches log events with the `ErrorRecord` property if available.

```ps1
Add-EnrichWithErrorRecord
    -LoggerConfig <LoggerConfiguration>
    [-DestructureObjects]
    [<CommonParameters>]
```

## Description

Adds the `ErrorRecord` property to log events. Use the `-ErrorRecord` parameter on `Write-*Log` cmdlets to attach an `ErrorRecord`, which will then appear as a structured property on the log event when this enricher is enabled.

`InvocationInfo` contains command names, script paths, line numbers and other scalar execution metadata. Bound parameter values, unbound argument values, source lines, display script positions and position messages are omitted in both text and destructured output. Raw argument capture has no built-in opt-in (ADR 0023). Applications that need selected values can add explicitly reviewed properties themselves. Error messages, exception details and target objects are still supplied by the caller and may contain sensitive data; this is not general-purpose redaction of arbitrary error content.

Constructed error records may have no invocation metadata. Their error details are still logged, with a null `InvocationInfo`. An omitted `MessageTemplate` on any `Write-*Log -ErrorRecord` call becomes an empty template; `-PassThru` formats the same empty template.

> Implemented as the compiled `AddEnrichWithErrorRecordCommand` cmdlet class (`src/dotnet/Cmdlets/Enrichers/AddEnrichWithErrorRecordCommand.cs`).

## Examples

##### Example 1: Log an ErrorRecord as a structured property

```ps1
New-Logger |
    Add-EnrichWithErrorRecord |
    Add-SinkConsole -OutputTemplate '[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}{Properties:j}' |
    Start-Logger

try {
    throw 'error'
}
catch {
    Write-ErrorLog -ErrorRecord $_
}
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

##### `-DestructureObjects`

If set, the ErrorRecord property will be destructured (captured as structured data) rather than serialized with `ToString()`.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |
