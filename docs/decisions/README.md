# Architectural decisions

One record per decision, numbered in order; a change of mind is a new record that supersedes the old one.

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-binary-module-net8-powershell-7-4.md) | v3 is a binary module on net8.0 for PowerShell 7.4+ | accepted |
| [0002](0002-sinks-and-enrichers-in-v3.md) | Which sinks and enrichers v3 keeps | accepted |
| [0003](0003-keep-the-v2-extension-contract.md) | v3 keeps the v2 extension contract | accepted, amended by 0009, 0010 |
| [0004](0004-refreshed-extensions-require-poshlog-3.md) | Refreshed extensions require PoShLog 3 | accepted |
| [0005](0005-psobject-destructuring-policy.md) | Destructure PowerShell objects as PowerShell users see them | accepted |
| [0006](0006-push-logcontextproperty-scope.md) | Push-LogContextProperty scopes with a script block or a bookmark | accepted |
| [0007](0007-clef-formatter-in-core.md) | Core writes CLEF with its own formatter | accepted |
| [0008](0008-powershell-sink-streams.md) | The PowerShell sink shows Error and Fatal like Write-Host | accepted |
| [0009](0009-first-party-sinks-third-party-check-non-blocking.md) | First-party sinks; other authors' sinks are a non-blocking check | accepted |
| [0010](0010-v2-maintenance-line.md) | v2 stays a maintained line for Windows PowerShell 5.1 | accepted |
| [0011](0011-core-does-not-load-assemblies-extensions-ship.md) | Core does not load assemblies that published extensions ship | accepted |
| [0012](0012-otlp-sink-design.md) | The OpenTelemetry sink: a compiled cmdlet, OTLP/HTTP by default, parameters before environment | accepted |
| [0013](0013-splunk-hec-sink-design.md) | The Splunk HEC sink: compiled cmdlet, own batching, migration aliases | accepted |
| [0014](0014-syslog-sink-design.md) | The Syslog sink: the package's formatters, our own transports | accepted |
| [0015](0015-elastic-sink-design.md) | The Elastic sink: data streams over the bulk API, dropping when the buffer is full | accepted |
| [0016](0016-convert-logfunctions-conservative.md) | Convert-LogFunctions is a conservative, reviewable helper | accepted |
| [0017](0017-extensions-require-poshlog-2-99-while-core-is-prerelease.md) | Extensions require PoShLog 2.99.0 while Core 3 is a prerelease | accepted |
| [0018](0018-release-modules-by-tag.md) | Release modules by pushing a tag | accepted |
| [0019](0019-extensions-ship-as-prereleases-during-the-core-3-preview.md) | Extensions ship as prereleases during the Core 3 preview | accepted |
| [0020](0020-integration-tests-against-real-backends.md) | Integration tests against real backends | proposed |
| [0021](0021-extension-catalog-in-core.md) | Core lists and installs its extensions from a catalogue built into the assembly | proposed |
| [0022](0022-documentation-website.md) | A Starlight documentation website built from docs/, served from the PoShLog.github.io org site | proposed |
| [0023](0023-safe-error-metadata-and-event-source-management.md) | Safe error invocation metadata and explicit Event Log source management | proposed |
| [0026](0026-powershell-file-paths.md) | Resolve file sink paths through the PowerShell provider | Proposed |
| [0027](0027-conditional-sublogger-expressions.md) | Filter sublogger routing with Serilog expressions | Proposed |
| [0028](0028-json-logger-configuration.md) | Load a Serilog JSON configuration snapshot | Proposed |
