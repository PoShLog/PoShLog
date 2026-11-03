# Install-PoShLogExtension

Installs first-party PoShLog extensions with `Install-PSResource`.

```ps1
Install-PoShLogExtension
    [-Name] <String[]>
    [-Scope <String>]
    [-Repository <String[]>]
    [-Prerelease]
    [-TrustRepository]
    [-PassThru]
    [-WhatIf]
    [-Confirm]
    [<CommonParameters>]
```

## Description

Installs the named extensions with `Install-PSResource` from PSResourceGet, which ships with PowerShell 7.4. While
this PoShLog build is a prerelease, it passes `-Prerelease`, so the preview extensions and their PoShLog dependency
resolve without you having to know the preview rules
([ADR 0019](../decisions/0019-extensions-ship-as-prereleases-during-the-core-3-preview.md),
[ADR 0021](../decisions/0021-extension-catalog-in-core.md)).

Only names from [`Get-PoShLogExtension`](Get-PoShLogExtension.md) are accepted; any other name is an error and the
remaining names are still installed. An extension whose platforms do not include the current OS (for example
PoShLog.Sinks.EventLog on Linux) is installed with a warning.

The command never asks for anything beyond what `-Confirm` and an untrusted repository ask, so it runs in CI and
scheduled jobs. PSGallery is untrusted by default; pass `-TrustRepository` in a non-interactive session.

> Implemented as the compiled `InstallPoShLogExtensionCommand` cmdlet class (`src/dotnet/Cmdlets/Extensions/InstallPoShLogExtensionCommand.cs`).

## Examples

##### Example 1: Install the Seq sink

```ps1
Install-PoShLogExtension PoShLog.Sinks.Seq
```

##### Example 2: See what would happen

```ps1
Install-PoShLogExtension PoShLog.Sinks.Seq -WhatIf
```

Example output:

```
What if: Performing the operation "Install-PSResource -Prerelease" on target "PoShLog.Sinks.Seq".
```

##### Example 3: Install every sink for all users in a build agent

```ps1
Get-PoShLogExtension | Where-Object Kind -eq Sink | Install-PoShLogExtension -Scope AllUsers -TrustRepository -Confirm:$false
```

## Parameters

##### `-Name`

Extension names, for example `PoShLog.Sinks.Seq`. Tab completion offers the catalogue.

|||
|-|-|
| Type: | String[] |
| Position: | 0 |
| Default value: | None |
| Accept pipeline input: | True (ByValue, ByPropertyName) |
| Accept wildcard characters: | False |

##### `-Scope`

`CurrentUser` (the default of `Install-PSResource`) or `AllUsers`.

|||
|-|-|
| Type: | String |
| Position: | Named |
| Default value: | CurrentUser |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Repository`

The PSResourceGet repositories to install from. By default the registered repositories by priority.

|||
|-|-|
| Type: | String[] |
| Position: | Named |
| Default value: | None |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-Prerelease`

Install prerelease versions also when this PoShLog build is stable.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False (True while PoShLog is a prerelease) |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-TrustRepository`

Install without asking whether to trust the repository. Needed in a non-interactive session for an untrusted
repository such as the default PSGallery.

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

##### `-PassThru`

Return the installed resources (the extension and dependencies such as PoShLog itself).

|||
|-|-|
| Type: | SwitchParameter |
| Position: | Named |
| Default value: | False |
| Accept pipeline input: | False |
| Accept wildcard characters: | False |

## Outputs

None, or with `-PassThru` the `PSResourceInfo` objects from `Install-PSResource`.

## Related

- [Get-PoShLogExtension](Get-PoShLogExtension.md)
- [Compatibility and installing](../compatibility.md)
