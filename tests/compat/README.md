# Extension compatibility

Run from the repository root, after publishing Core to src/lib and building all four extensions:

```powershell
./tests/compat/Invoke-Compatibility.ps1 -Mode InRepo
```

The suite launches a fresh PowerShell process for each module. It verifies that Core preloads its
shared dependencies, that the extension returns the shared LoggerConfiguration, and that Core's
file sink receives the unique event. Seq and Http must also deliver that event to an HttpListener
on loopback. Enrichers must add environment and process properties. EventLog is Windows-only
and builds its sink configuration without creating an event source or writing to the log.

Published mode is restricted to GitHub Actions. It downloads exact package versions without
resolving Gallery dependencies, then explicitly imports freshly built Core first. The reusable
compat.yml workflow runs InRepo and Published on Windows and Linux. CI and the manual release
workflow both depend on it; any download, import, configuration or delivery failure fails the job.

| Published module | Version | Assertion |
|---|---|---|
| PoShLog.Enrichers | 1.0.0 | Enriched event in file |
| PoShLog.Sinks.Seq | 1.0.0 | Event at loopback HTTP listener |
| PoShLog.Sinks.EventLog | 1.0.0 | Import and sink configuration, Windows only |
| PoShLog.Sinks.Http | 1.0.1 | Event at loopback HTTP listener |
| PoShLog.Sinks.Exceptionless | 1.0.0 | Event at loopback HTTP listener |
| PoShLog.Sinks.Syslog | 1.0.0 | Event at loopback UDP listener |
| PoShLog.Sinks.DataDog | 0.1.1 | Event at loopback HTTP listener; skipped on Linux (RootModule case mismatch in its manifest, fails with any PoShLog version) |
| PoShLog.Sinks.ElmahIo | 4.0.4 | Import and sink configuration; wrapper has no endpoint override |
| PoShLog.Sinks.Splunk | 1.0.4 | Event at loopback HTTP listener |

No real credentials are used. Cloud endpoints are not contacted. Only processes and listeners
created by the suite are closed. The driver imposes a per-module timeout; delivery assertions
have a 30-second deadline. Generated files stay in the ignored .compat/ directory.
