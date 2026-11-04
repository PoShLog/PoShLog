# FAQ and troubleshooting

## My events do not show up

1. **Is the logger closed?** File and network sinks write in batches. Call [`Close-Logger`](../cmdlets/Close-Logger.md)
   at the end of the script, in a `finally` block, so the last events are flushed.
2. **Is the level high enough?** The default minimum level is `Information`, so `Write-VerboseLog` and
   `Write-DebugLog` are dropped unless you call [`Set-MinimumLevel`](../cmdlets/Set-MinimumLevel.md). A sink can also
   have its own `-RestrictedToMinimumLevel`.
3. **Does the PowerShell sink hide them?** [`Add-SinkPowerShell`](../cmdlets/Add-SinkPowerShell.md) writes to the
   PowerShell streams, so `$VerbosePreference` and `$InformationPreference` decide what is shown.
4. **Is a sink failing?** Logging never throws into your script. Turn on [`Enable-SelfLog`](../cmdlets/Enable-SelfLog.md)
   to see why a server, a file or a template is rejected.

## Why single quotes in the message?

The message is a template: `'Copied {Count} files'` with `-PropertyValues 42`. In double quotes PowerShell would expand
`$variables` before PoShLog sees the text, and the value would not be kept as a property. See
[Usage](../usage.md).

## How do I log an object?

Put `@` in front of the property name to keep its structure: `Write-InfoLog 'Checked {@Service}' -PropertyValues $service`.
Without `@`, the object is logged as its string. See [Usage](../usage.md#log-objects).

## Where is my rolling log file?

With `-RollingInterval Day` the date is added to the file name. [`Get-CurrentLogFiles`](../cmdlets/Get-CurrentLogFiles.md)
returns the current paths.

## Which extensions are there, and how do I install them?

[`Get-PoShLogExtension`](../cmdlets/Get-PoShLogExtension.md) lists them; [`Install-PoShLogExtension`](../cmdlets/Install-PoShLogExtension.md)
installs one, as a prerelease while PoShLog 3 is in preview. See [Compatibility and installation](../compatibility.md).

## Does PoShLog 3 work on Windows PowerShell 5.1?

Support is coming with the Windows PowerShell build and is not released yet. The upcoming v3 builds target
PowerShell 7.6+ (.NET 10) and Windows PowerShell 5.1 (.NET Framework 4.7.2+). See
[Assembly conflicts](assembly-conflicts.md) for import-order guidance and [v2 or v3?](../v2-or-v3.md) for the existing lines.

## Can I use a Serilog sink that has no PoShLog module?

Yes, as an advanced route: load the sink's assembly and call its `WriteTo` extension on the logger configuration. The
constraints are in the [migration guide](migration-v3.md).

## A sink module fails to import with an assembly error

Another module may have loaded an older shared assembly first. Start a fresh session and import PoShLog before
that module. See [Assembly conflicts](assembly-conflicts.md) for the differences between PowerShell 7.6+ and the
upcoming Windows PowerShell build, how to inspect loaded DLLs, and what to include in a bug report.

## Where do I ask?

Open an issue or a discussion on [GitHub](https://github.com/PoShLog/PoShLog), or join the
[Discord](https://discord.gg/FVdVxuw).
