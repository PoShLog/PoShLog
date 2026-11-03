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

Published and ThirdParty modes are restricted to GitHub Actions. They download exact package
versions without resolving Gallery dependencies, then explicitly import freshly built Core first.
The reusable compat.yml workflow runs all three modes on Windows and Linux. InRepo and Published
(our own published extensions) block CI and the manual release workflow. ThirdParty (other
authors' sinks) runs with continue-on-error: failures are annotated but gate nothing (ADR 0009).

| Published module (mode) | Version | Assertion |
|---|---|---|
| PoShLog.Enrichers (Published) | 1.0.0 | Enriched event in file |
| PoShLog.Sinks.Seq (Published) | 1.0.0 | Event at loopback HTTP listener |
| PoShLog.Sinks.EventLog (Published) | 1.0.0 | Import and sink configuration, Windows only |
| PoShLog.Sinks.Http (Published) | 1.0.1 | Event at loopback HTTP listener |
| PoShLog.Sinks.OpenTelemetry (InRepo build, both modes) | 0.1.0 | Event at loopback OTLP/HTTP `/v1/logs`; also next to Seq (InRepo: refreshed Seq; Published: Seq 1.0.0), each imported first and after, both delivering |
| PoShLog.Sinks.Splunk.Hec (InRepo build, both modes) | 0.1.0 | Event at loopback HEC `/services/collector/event`; also next to Seq, like OpenTelemetry |
| PoShLog.Sinks.Exceptionless (Published) | 1.0.0 | Event at loopback HTTP listener |
| PoShLog.Sinks.Syslog (ThirdParty) | 1.0.0 | Event at loopback UDP listener |
| PoShLog.Sinks.DataDog (ThirdParty) | 0.1.1 | Event at loopback HTTP listener; skipped on Linux (RootModule case mismatch in its manifest, fails with any PoShLog version) |
| PoShLog.Sinks.ElmahIo (ThirdParty) | 4.0.4 | Import and sink configuration; wrapper has no endpoint override |
| PoShLog.Sinks.Splunk (ThirdParty) | 1.0.4 | Event at loopback HTTP listener |

Each case runs with its own .compat/<marker> folder as the working directory: Seq 1.0.0 passes an empty buffer
file name, ships durably and writes -YYYYMMDD.json and .bookmark there.

No real credentials are used. Cloud endpoints are not contacted. Only processes and listeners
created by the suite are closed. The driver imposes a per-module timeout; delivery assertions
have a 30-second deadline. Generated files stay in the ignored .compat/ directory.
