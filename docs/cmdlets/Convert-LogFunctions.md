# Convert-LogFunctions

Optional helper for reviewing simple logging command rewrites. It is **not part of the recommended migration path**.
Initialize and configure the logger yourself, review every proposed change, and test the resulting script.

```ps1
Convert-LogFunctions -Path <string> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## Conservative conversion rules

The helper parses the whole file with PowerShell's parser. Parse errors produce an error record and leave the
file untouched. It changes only literal command-name extents and parameter names, case-insensitively:

| From | To | Message parameter |
|------|----|-------------------|
| `Write-Verbose` | `Write-VerboseLog` | `-Message` → `-MessageTemplate` |
| `Write-Debug` | `Write-DebugLog` | `-Message` → `-MessageTemplate` |
| `Write-Information` | `Write-InfoLog` | `-MessageData` → `-MessageTemplate` |
| `Write-Host` | `Write-InfoLog` | `-Object` → `-MessageTemplate` |
| `Write-Warning` | `Write-WarningLog` | `-Message` → `-MessageTemplate` |

Unambiguous parameter prefixes are accepted; supported common parameters are expanded to their full names.
Positional messages remain positional. Strings, comments, here-strings, variable names and function declaration
names are not rewritten. Literal calls inside function bodies are still considered.

Each `Write-Error` call is skipped: logging cannot preserve its error-stream semantics, `$?`, `-ErrorAction Stop`
or try/catch behavior. Calls with unsupported parameters (including `Write-Host -ForegroundColor`, `-NoNewline`
and `Write-Information -Tags`), splatting, or pipeline input are skipped with a reason. Invocation operators,
redirections, ambiguous/unknown parameters, missing messages and multiple message arguments also require manual review.
The helper does not resolve function shadowing or aliases, initialize a logger, escape message-template braces,
or prove semantic equivalence. Even an accepted call needs review.

Before a write, the original is copied to `<file>.bak`. An existing backup causes an error unless `-Force` is
specified. Encoding, BOM and line endings are preserved; invalid encoded input is refused. **Keep the `.bak`
until the converted script has been tested.** Files with no accepted conversions are not written or backed up.

## Output and review

One object per finding has `File`, `Line`, `Command`, `Action` (`Converted` or `Skipped`), `Before`, `After`, and
`Reason`. `Before` and `After` show the command text. With `-WhatIf` or declined confirmation, accepted findings
are reported as `Skipped`; `After` still shows the proposed change. No file or backup is written.

```ps1
# Inspect the proposed diff first.
Convert-LogFunctions -Path './script.ps1' -WhatIf | Format-List

# Apply, review the diff, then test before removing script.ps1.bak.
Convert-LogFunctions -Path './script.ps1' -Confirm | Format-List

# FileInfo.FullName binds directly.
Get-ChildItem './scripts/*.ps1' | Convert-LogFunctions -WhatIf
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `-Path <string>` | Mandatory literal file path; accepts strings by value and `FullName` by pipeline property name. Wildcards are not expanded. `-FilePath` is a compatibility alias. |
| `-Force` | Allows replacement of an existing `.bak`. Does not bypass ShouldProcess or conservative checks. |
| `-WhatIf` | Reports proposed changes without writing anything. |
| `-Confirm` | Requests confirmation before backing up and converting each file. |
