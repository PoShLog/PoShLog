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

No. PoShLog 3 needs PowerShell 7.6 or newer, on Windows, Linux or macOS. Windows PowerShell 5.1 stays on the
maintained 2.x line; see [v2 or v3?](../v2-or-v3.md).

## Can I use a Serilog sink that has no PoShLog module?

Yes, as an advanced route: load the sink's assembly and call its `WriteTo` extension on the logger configuration. The
constraints are in the [migration guide](migration-v3.md).

## A sink module fails to import with an assembly error

The first-party extensions reuse a .NET assembly that is already loaded in the session at the same or a newer
version. When an older version is loaded, for example by another module imported earlier, the import fails with a
message that names both versions. Start a new session and import the PoShLog extension before that module. Background:
[ADR 0011](../decisions/0011-core-does-not-load-assemblies-extensions-ship.md) and
[ADR 0012](../decisions/0012-otlp-sink-design.md).

## Where do I ask?

Open an issue or a discussion on [GitHub](https://github.com/PoShLog/PoShLog), or join the
[Discord](https://discord.gg/FVdVxuw).
