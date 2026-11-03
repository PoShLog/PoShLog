# Recipe: GitHub Actions

A CI step that writes short, readable lines to the job log and every event, Debug included, as structured JSON to a
file. The workflow uploads the file as an artifact, turns warnings and errors into annotations, and the step's exit
code, not the log level, decides whether the job fails.

Samples in [samples/github-actions/](../../samples/github-actions/):

- [Test-JsonFiles.ps1](../../samples/github-actions/Test-JsonFiles.ps1) checks that every JSON file under a folder
  parses.
- [Write-LogAnnotations.ps1](../../samples/github-actions/Write-LogAnnotations.ps1) reads the log file and writes the
  annotations and a job summary. It needs no module.
- [check-json.yml](../../samples/github-actions/check-json.yml) is the workflow.

## The workflow

```yaml
name: Check JSON

on:
  push:
  pull_request:

defaults:
  run:
    shell: pwsh

jobs:
  check:
    runs-on: ubuntu-latest
    env:
      # Pin the version you tested with.
      POSHLOG_VERSION: 3.0.0-preview2
    steps:
      - uses: actions/checkout@v4

      - name: Install PoShLog
        run: Install-PSResource PoShLog -Version $env:POSHLOG_VERSION -Prerelease -TrustRepository

      - name: Check JSON files
        run: ./scripts/Test-JsonFiles.ps1 -Path ./config -LogPath "$env:RUNNER_TEMP/poshlog/test-json.clef"

      - name: Annotate warnings and errors
        if: always()
        run: ./scripts/Write-LogAnnotations.ps1 -Path "$env:RUNNER_TEMP/poshlog/test-json.clef"

      - name: Upload the log
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: poshlog-${{ github.job }}-${{ github.run_attempt }}
          path: ${{ runner.temp }}/poshlog/
          if-no-files-found: warn
```

- The hosted runners have PowerShell 7.4+ and PSResourceGet. Pin the PoShLog version so that a new release does not
  change a build on its own; see [Compatibility and installation](../compatibility.md).
- The log goes to `RUNNER_TEMP`, outside the checkout, so it is never committed or picked up by other steps.
- `if: always()` runs the last two steps also when the check fails, which is when the log matters most.

## The logger

```powershell
New-Logger |
    Set-MinimumLevel -Value Debug |
    Add-EnrichWithProperty -Name Workflow -Value ($env:GITHUB_WORKFLOW ?? 'local') |
    Add-EnrichWithProperty -Name RunId -Value ($env:GITHUB_RUN_ID ?? 'local') |
    # The job log adds its own timestamps; Debug events go only to the file.
    Add-SinkConsole -RestrictedToMinimumLevel Information -OutputTemplate '[{Level:u3}] {Message:lj}{NewLine}{Exception}' |
    Add-SinkFile -Path $LogPath -Formatter (Get-CompactFormatter -Rendered) |
    Start-Logger

$exitCode = 0
try {
    # ... Write-WarningLog '{File} is empty', Write-ErrorLog '{File} is not valid JSON: {Reason}' ...
    if ($invalid -gt 0) {
        Write-ErrorLog '{InvalidCount} of {FileCount} files are not valid JSON' -PropertyValues $invalid, $files.Count
        $exitCode = 1
    }
}
catch {
    Write-FatalLog 'The check could not run' -ErrorRecord $_
    $exitCode = 2
}
finally {
    Close-Logger
}
# A non-zero exit code fails the step; the log level alone does not.
exit $exitCode
```

- The console sink starts at Information and drops the timestamp, because the job log has its own.
- `Get-CompactFormatter -Rendered` writes one JSON object per line (CLEF) with the rendered message in `@m`, the level
  in `@l`, the exception in `@x` and every property, the enriched `Workflow` and `RunId` included.
- Exit code 1 means "the check found problems" and 2 means "the check could not run". Both fail the step.

## Expected output

The job log of a run with one broken and one empty file; the step fails with exit code 1:

```text
[INF] Checking 3 JSON files under ./config
[ERR] broken.json is not valid JSON: Conversion from JSON failed with error: Unexpected end when deserializing object. Path 'name', line 3, position 0.
[WRN] empty.json is empty
[ERR] 1 of 3 files are not valid JSON
```

A line of the CLEF file (the artifact), here the warning:

```json
{"@t":"2026-11-03T12:09:01.4410000Z","@m":"\"empty.json\" is empty","@i":"cb53fb76","@l":"Warning","File":"empty.json","Workflow":"Check JSON","RunId":"4242"}
```

The rendered message in `@m` quotes string values; the console template uses `:lj`, which does not.

The annotation step writes these workflow commands. GitHub shows them on the run's summary page and on the pull request:

```text
::error title=PoShLog Error::"broken.json" is not valid JSON: "Conversion from JSON failed with error: Unexpected end when deserializing object. Path 'name', line 3, position 0."
::warning title=PoShLog Warning::"empty.json" is empty
::error title=PoShLog Error::1 of 3 files are not valid JSON
```

and adds this table to the job summary:

| Level | Events |
|---|---:|
| Debug | 1 |
| Information | 1 |
| Warning | 1 |
| Error | 2 |

## Without the annotation script

To annotate only a few known places, write the workflow command yourself next to the log event:

```powershell
Write-WarningLog '{File} is empty' -PropertyValues $relative
"::warning file=$relative,title=Empty JSON::$relative is empty"
```

Escape `%`, CR and LF in the message as `%25`, `%0D` and `%0A`, or the command ends at the first line break.

## Missing events?

- **The artifact is empty or missing.** The log file is written to `RUNNER_TEMP` only by the step that runs the script;
  check that `-LogPath` and the upload `path` name the same folder. `upload-artifact` without `if: always()` does not
  run after a failed step.
- **The last events are missing from the file.** `Close-Logger` flushes it. Keep it in `finally`, and do not call
  `exit` inside `try`.
- **Debug events are not in the job log.** That is on purpose: `-RestrictedToMinimumLevel Information` on the console
  sink. They are in the file, as long as `Set-MinimumLevel` is Debug.
- **The step is green although errors were logged.** The log level does not fail a step; the exit code does. Set it
  with `exit`: `shell: pwsh` ends the step with the last `$LASTEXITCODE`, so the script's exit code fails the step. A
  `throw` outside `try` fails it too, but then `Close-Logger` does not run.
- **Only ten annotations show.** GitHub shows at most 10 warning and 10 error annotations per step. The rest are in the
  CLEF file and in the summary count.
- **An annotation is cut off after the first line.** The message was not escaped; see above.
- **`Install-PSResource` cannot find the version.** Prerelease versions need `-Prerelease`, and the version must exist
  on the PowerShell Gallery.
- **Still nothing.** Call `Enable-SelfLog` before `Start-Logger`; Serilog then writes its own errors to the job log.

## Verified

`build/Test-Recipes.ps1` runs both scripts against the staged package, in a new `pwsh` process with `GITHUB_WORKFLOW`,
`GITHUB_RUN_ID` and `GITHUB_STEP_SUMMARY` set. It checks the exit codes, the console lines, the CLEF events with their
properties, the annotation lines with their escaping and the summary table. The workflow file itself is not run; its
steps match the ones the check runs.
