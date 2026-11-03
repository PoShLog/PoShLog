# Recipes

Copy-paste setups for PoShLog 3 in automation. Each recipe has a runnable sample under [samples/](../../samples/), the
output it produces, and a "Missing events?" section for when the log is not what you expected.

| Recipe | What it shows |
|---|---|
| [A scheduled script](scheduled-script.md) | Task Scheduler or cron; console and a daily rolling file; `Close-Logger` in `finally`; exit codes the scheduler shows |
| [GitHub Actions](github-actions.md) | Readable job log, a structured CLEF file as an artifact, annotations for warnings and errors, the exit code fails the step |
| [Testing code that logs, with Pester](pester.md) | Mocking the logging commands, or capturing the real events and their properties |

The samples need PowerShell 7.4+ and PoShLog 3.0.0-preview2 or newer. See [Compatibility and installation](../compatibility.md).

## How the samples are checked

`build/Test-Recipes.ps1` stages the module from this repository the way a release does and runs every sample in a new
`pwsh` process against it ([samples/Recipes.Tests.ps1](../../samples/Recipes.Tests.ps1)). CI runs it on Linux and
Windows.

```powershell
dotnet publish src/dotnet/PoShLog.Core.csproj -c Release -o src/lib
./build/Test-Recipes.ps1
```
