# Get-PoShLogExtension

Lists the first-party PoShLog extensions with their commands and the installed version.

```ps1
Get-PoShLogExtension
    [[-Name] <String[]>]
    [-Online]
    [-Repository <String[]>]
    [<CommonParameters>]
```

## Description

PoShLog knows its own extensions: the build embeds the manifests from `extensions/` into the module, so the list
matches the PoShLog version you have and needs no network ([ADR 0021](../decisions/0021-extension-catalog-in-core.md)).
Each entry has the module name, whether it is a sink or an enricher, the version that belongs to this PoShLog build,
a one-line summary, the commands it adds, the supported platforms and `CompatiblePSEditions`, the project URL and the installed version (the
newest one `Get-Module -ListAvailable` finds, or empty).

`-Online` also asks the repository for the latest published version with `Find-PSResource` from PSResourceGet. While
PoShLog is a prerelease it looks for prereleases too.

Only first-party extensions are listed. Other authors' modules are on the [sinks page](../sinks/README.md).
Current in-repo extension manifests declare Core edition and require PowerShell 7.6+. Desktop ports are separate work.

> Implemented as the compiled `GetPoShLogExtensionCommand` cmdlet class (`src/dotnet/Cmdlets/Extensions/GetPoShLogExtensionCommand.cs`).

## Examples

##### Example 1: What can I add to PoShLog?

```ps1
Get-PoShLogExtension | Format-Table Name, Kind, Version, InstalledVersion, Commands
```

Example output:

```
Name                         Kind     Version        InstalledVersion Commands
----                         ----     -------        ---------------- --------
PoShLog.Enrichers            Enricher 2.0.0-preview2                  {Add-EnrichWithEnvironment, Add-EnrichWithExceptionDetails, …}
PoShLog.Sinks.Elastic        Sink     0.1.0-preview2                  {Add-SinkElasticsearch}
PoShLog.Sinks.EventLog       Sink     2.0.0-preview2                  {Add-SinkEventLog}
PoShLog.Sinks.Http           Sink     2.0.0-preview2                  {Add-SinkHttp}
PoShLog.Sinks.OpenTelemetry  Sink     0.1.0-preview2                  {Add-SinkOpenTelemetry}
PoShLog.Sinks.Seq            Sink     2.0.0-preview2 2.0.0-preview2   {Add-SinkSeq}
PoShLog.Sinks.Splunk.Hec     Sink     0.1.0-preview2                  {Add-SinkSplunk}
PoShLog.Sinks.Syslog.Rfc5424 Sink     0.1.0-preview2                  {Add-SinkSyslog}
```

##### Example 2: Details of one extension

```ps1
Get-PoShLogExtension *Seq* | Format-List *
```

##### Example 3: Is there a newer version?

```ps1
Get-PoShLogExtension -Online | Where-Object { $_.InstalledVersion -and $_.InstalledVersion -ne $_.LatestVersion }
```

## Parameters

##### `-Name`

Extension names. Wildcards are allowed; the names start with `PoShLog.`, so use `*Seq*` rather than `Seq*`. A name
without a wildcard that is not in the catalogue is an error.

|||
|-|-|
| Type: | String[] |
| Position: | 0 |
| Default value: | All extensions |
| Accept pipeline input: | True (ByValue, ByPropertyName) |
| Accept wildcard characters: | True |

##### `-Online`

Also look up the latest version in the repository with `Find-PSResource`. A repository error becomes a warning.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Repository`

The PSResourceGet repositories `-Online` searches. By default all registered repositories.

|||
|-|-|
| Type: | String[] |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

## Outputs

`PoShLog.Core.Catalog.ExtensionEntry` with `Name`, `Kind`, `Version`, `Summary`, `Commands`, `Platforms`,
`ProjectUri`, `InstalledVersion` and, with `-Online`, `LatestVersion`.

## Related

- [Install-PoShLogExtension](Install-PoShLogExtension.md)
- [Compatibility and installing](../compatibility.md)
