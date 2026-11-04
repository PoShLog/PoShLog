# Integration tests

These opt-in Pester 5 tests verify delivery of Information, Warning and Error events (including an ErrorRecord),
their rendered messages and structured properties. Ordinary CI discovery does not activate them.

Requirements: Docker with Linux containers, PowerShell 7.6+, .NET SDK 10 (InRepo; builds the net10.0
module for the PowerShell 7.6 host), and access to PSGallery/NuGet. Allow about 6 GB RAM for the containers.

```powershell
docker compose -f tests/integration/compose.yml up -d --wait
./build/Invoke-IntegrationTests.ps1 -Source Gallery -Prerelease
./build/Invoke-IntegrationTests.ps1 -Source InRepo
docker compose -f tests/integration/compose.yml down -v
```

Use `-Module PoShLog.Sinks.Seq,PoShLog.Sinks.OpenTelemetry` to select tests. Core is always staged as a dependency.
Gallery uses `Save-PSResource -Path` into a unique temp folder; InRepo uses CI's Core publish and
`build/Stage-Module.ps1` (which builds extensions). Resolved versions and Pester XML are saved under
`TestResults/integration`. Every module runs in a fresh process with only that folder and `$PSHOME/Modules` on
PSModulePath. Temp module folders are removed even on failure. No profile module installation is performed.

Seq, Elasticsearch, Splunk, OTLP HTTP/gRPC and syslog UDP/TCP/TLS run in pinned containers bound to loopback.
Collector and syslog output use mounted Docker volumes; inspect with `docker compose ... exec -T collector cat
/output/logs.jsonl` or `docker compose ... exec -T syslog cat /output/tls.jsonl`. Syslog creates a short-lived TLS
key inside its container at startup; only its public certificate is read by the tests. Elasticsearch security is off.
Splunk uses fixed dummy credentials and a test-only handler for its self-signed certificate. These settings are
only suitable for disposable local containers. HTTP uses a live loopback HttpListener so complete request bodies
can be asserted without another image. Enrichers are asserted using the Core File sink's JSON formatter.

The EventLog test requires an elevated Windows process and creates/removes its own unique Application source:

```powershell
./build/Invoke-IntegrationTests.ps1 -Source Gallery -Prerelease -Module PoShLog.Sinks.EventLog
```

For Windows PowerShell 5.1, run `powershell.exe -NoProfile -File build/Invoke-LegacyIntegrationTests.ps1`.
It uses PowerShellGet's `Save-Module` (same resolution as `Install-Module`, with a temp destination), asserts
Core 2.x and Seq/EventLog 1.0.x, tests File and real EventLog, and captures Seq `/api/events/raw` ingestion (1.0.x sends the `{"Events":[...]}` envelope)
with a live listener. It requires an existing NuGet provider, never bootstraps into the user profile, and needs
elevation for EventLog. A Windows runner cannot run Seq's Linux image; this verifies the ingestion contract,
not Seq's storage/query behavior. The Linux job verifies the actual Seq server.

The daily, manual and successful Release workflow runs use Gallery; PRs use InRepo. Release runs wait up to ten
minutes for the checked-out manifest versions to appear in Gallery. A temporary branch push trigger runs both.
GitHub jobs collect container logs/output and Pester results on failure, then remove containers and volumes.

SQL Server is an opt-in `mssql` Compose profile using mcr.microsoft.com/mssql/server:2022-CU18-ubuntu-22.04.
Set MSSQL_SA_PASSWORD to a freshly generated disposable credential in process memory, start the profile with
`docker compose -f tests/integration/compose.yml --profile mssql up -d --wait mssql`, and set
POSHLOG_SQL_CONNECTION_STRING for the test child. CI does this within the integration-test step; it does not persist
or print the credential. The SQL test reads levels, messages, properties, JSON, an exception and an additional column.
Use `--profile mssql down -v` to remove the test backend after the run.
