# Logger configuration from JSON

`New-Logger -ConfigurationPath ./logging.json` reads a supported Serilog configuration
once, then returns a configuration that can continue through the usual pipeline.
The JSON file path resolves against the current PowerShell FileSystem location.
Windows PowerShell 5.1 supports the non-expression subset. Nonempty JSON `Filter` entries fail with a clear
Windows PowerShell error. Extension methods require an extension build compatible with the current host.

```json
{
  "Serilog": {
    "MinimumLevel": "Warning",
    "WriteTo": [
      { "Name": "Console" }
    ],
    "Properties": { "Application": "backup" }
  }
}
```

```powershell
New-Logger -ConfigurationPath ./logging.json |
    Add-SinkFile -Path './logs/backup.log' |
    Start-Logger
Write-InfoLog 'Below the configured level'
Write-WarningLog 'Backup needs attention'
Close-Logger
```

The Console and File sinks are available without extra modules. A File entry uses
`"Name": "File", "Args": { "path": "C:/Logs/backup.log" }`. Use absolute paths
for extension buffer paths inside JSON. Core `File` paths, like `ConfigurationPath`,
resolve against the PowerShell FileSystem location at configuration time.

PoShLog reads a supported subset of the Serilog JSON schema with `System.Text.Json`,
without loading `Microsoft.Extensions.Configuration` assemblies that conflict with
published extensions (ADR 0028). Property names in the schema are case sensitive.

Supported sections:

- `MinimumLevel`: a level name, or an object with `Default` and `Override` values.
- `Properties`: scalar or structured static properties.
- `WriteTo`, `Enrich`, `Filter`: arrays of method names or `{ "Name": "...", "Args": { ... } }` calls.
- `Using`: optional names of assemblies that must already be loaded; no automatic assembly or module import.

Method names match public Serilog extension methods. Argument names are case
insensitive. Arguments can be strings, booleans, numbers, enum names, nullable
scalars, invariant TimeSpan strings (for example `00:00:02`) and absolute URI strings.
Omitted optional parameters keep their .NET defaults. Exactly one overload must match.

Not supported in JSON: `LevelSwitches`, `FilterSwitches`, `AuditTo`, `Destructure`,
nested logger callbacks, custom formatter/theme objects, configuration object arguments,
or arbitrary type construction. Unknown sections, methods and arguments fail explicitly.
Use the PowerShell pipeline for these configurations. This is not a drop-in replacement
for every `Serilog.Settings.Configuration` option; see the
[upstream schema](https://github.com/serilog/serilog-settings-configuration) for comparison.

On PowerShell 7.6+, the expression engine is incorporated into Core, so filters can use `ByIncludingOnly` and `ByExcluding`.

```json
{ "Serilog": { "Filter": [{ "Name": "ByIncludingOnly", "Args": { "expression": "Send = true" } }] } }
```

## Extensions

Import extension modules **before** `New-Logger -ConfigurationPath`. The reader
discovers public Serilog configuration extension methods in assemblies already loaded in the default context
on PowerShell 7. On Desktop it discovers loaded, nondynamic AppDomain assemblies.
It does not install extensions. `Using` entries assert that assemblies are already loaded;
they do not import PowerShell modules or add assemblies to the process.

| Component | JSON support |
|---|---|
| Core File and Console | `File`, `Console` |
| Core PowerShell sink | Add `Add-SinkPowerShell` in the pipeline; its callback needs the host |
| PoShLog.Enrichers | Import first; e.g. `"Enrich": ["WithMachineName", "WithProcessId"]` |
| Seq, Http, EventLog | Import first; upstream public Serilog methods and argument names, e.g. `Seq`, `Http`, `EventLog` |
| OpenTelemetry and Elastic | Use the PoShLog cmdlets in the pipeline: their options/callback arguments are outside the supported scalar binding |
| Splunk.Hec and Syslog.Rfc5424 | Use their PoShLog cmdlets in the pipeline; custom PoShLog transport configuration is not a public JSON configuration API |
| Other extensions | Only public Serilog configuration methods in loaded assemblies; compatibility is not guaranteed |

Arguments follow the installed upstream version. For example, Serilog.Sinks.Http 9.2.1
requires `queueLimitBytes` even when its value is null:

```json
{ "Serilog": { "WriteTo": [{ "Name": "Http", "Args": { "requestUri": "http://127.0.0.1:8080/", "queueLimitBytes": null } }] } }
```

Example with a loaded enricher:

```powershell
Import-Module PoShLog.Enrichers
# logging.json contains: { "Serilog": { "Enrich": ["WithMachineName"] } }
New-Logger -ConfigurationPath ./logging.json |
    Add-SinkFile -Path './machine.log' -OutputTemplate '{MachineName} {Message:lj}{NewLine}' |
    Start-Logger
```

PoShLog's object destructuring still applies when `Start-Logger` creates the logger.
Pipeline configuration after loading JSON can add sinks and enrichers or set the
minimum level. This is a snapshot: editing the file does not reload a running logger.
Close the old logger and configure a new one to apply changes.

Missing files, malformed JSON, missing `Serilog` sections and invalid level values
fail configuration. Unknown or ambiguous methods and unsupported argument types also
fail instead of silently dropping a sink. Use [SelfLog](../cmdlets/Enable-SelfLog.md)
to diagnose runtime delivery failures. Treat configuration as trusted input: it can
configure network destinations. Keep credentials outside checked-in configuration files.
