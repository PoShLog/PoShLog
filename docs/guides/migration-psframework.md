# PoShLog and PSFramework

[PSFramework](https://psframework.org/) is a broad toolkit for module authors. Its logging (`Write-PSFMessage` and the
logging providers) is one part of it, next to configuration, tab completion, runspaces and more. PoShLog does one
thing: structured logging on [Serilog](https://serilog.net/). This page helps you decide, and shows how the common
logging calls map when you move a script.

## When to use which

- **You already build modules on PSFramework** and use its configuration and message system across them: keep it.
  Its messages integrate with the rest of the framework.
- **You want structured events in Seq, OpenTelemetry, Elasticsearch, Splunk or syslog**, with properties a backend can
  filter on, or you know Serilog from .NET: PoShLog sends events to those through Serilog sinks and keeps the
  property types.
- **You want a small dependency for scripts**: PoShLog is one module plus the sink modules you choose.

Both can live in the same session; they do not share a pipeline.

## Mapping the common calls

| PSFramework | PoShLog |
|---|---|
| `Write-PSFMessage -Level Verbose -Message '…'` | `Write-VerboseLog '…'` |
| `Write-PSFMessage -Level Debug -Message '…'` | `Write-DebugLog '…'` |
| `Write-PSFMessage -Level Host` / `Important` / `Significant` / `Output` | `Write-InfoLog '…'` |
| `Write-PSFMessage -Level Warning -Message '…'` | `Write-WarningLog '…'` |
| `Write-PSFMessage -Level Warning -Message '…' -ErrorRecord $_` | `Write-ErrorLog '…' -ErrorRecord $_` |
| `-Message 'Copied {0} files' -StringValues $count` | `'Copied {Count} files' -PropertyValues $count` |
| `-Tag 'backup'` | a property: `Add-EnrichWithProperty -Name Area -Value backup`, or `Push-LogContextProperty` for a block |
| `-Target $server` | a property in the template: `'Checking {Server}' -PropertyValues $server` |
| A logging provider (`Set-PSFLoggingProvider -Name logfile …`) | a sink: `Add-SinkFile`, `Add-SinkSeq`, `Add-SinkOpenTelemetry`, … |

PoShLog has no implicit logger. Configure one with [`New-Logger`](../cmdlets/New-Logger.md) … [`Start-Logger`](../cmdlets/Start-Logger.md)
at the start of the script and call [`Close-Logger`](../cmdlets/Close-Logger.md) at the end, so batched sinks flush.

## Example

```powershell
New-Logger |
    Set-MinimumLevel -Value Verbose |
    Add-EnrichWithProperty -Name Area -Value backup |
    Add-SinkConsole |
    Add-SinkFile -Path './logs/backup-.log' -RollingInterval Day |
    Start-Logger

try {
    Write-VerboseLog 'Checking {Server}' -PropertyValues 'sql01'
    Write-InfoLog 'Copied {Count} files' -PropertyValues 42
}
catch {
    Write-ErrorLog 'Backup of {Server} failed' -PropertyValues 'sql01' -ErrorRecord $_
    throw
}
finally {
    Close-Logger
}
```

## Next

- [Usage and message templates](../usage.md)
- [Enrichers](enrichers.md) and [`Push-LogContextProperty`](../cmdlets/Push-LogContextProperty.md)
- [Sinks](../sinks/README.md)
