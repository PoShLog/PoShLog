# Changelog

## 2.0.0-preview4 — 2026-11-05 (unreleased)

### Features
- Native non-durable HTTP delivery on Windows PowerShell 5.1 (.NET Framework 4.7.2+) and PowerShell 7.6+ (.NET 10).
- A legacy batch formatter restores the published 1.0.1 events envelope with a configurable 256-KiB event limit.

### Changes
- Replace Serilog.Sinks.Http and Microsoft.Extensions contracts with PoShLog-owned client and batch formatter interfaces; Configuration accepts IDictionary. Custom implementations need migration and recompilation.
- Omitted QueueLimit is now 100,000 events; explicit null remains unbounded. Default JSON stays compatible with the current array and normal rendered event schema.
- Every non-2xx response fails without following redirects. Requests have a 30-second timeout; Serilog owns retries and shutdown flushing.
- PowerShell 7.4 and 7.5 remain unsupported; use the earlier version or PoShLog 2.x with the 1.0.x extensions there. Upstream durable APIs and convenience clients are no longer supplied transitively.

### Bug fixes
- Restore TextFormatter as an alias of Formatter and preserve X-Api-Key authentication through Get-ApiKeyHttpClient or the http:apiKey dictionary entry.

## 2.0.0-preview3 — 2026-11-04

### Features
- No new features.

### Changes
- Released with PoShLog 3.0.0-preview3 (shared preview label, ADR 0019); the manifest describes the module in one line.

### Bug fixes
- Export the manifest-declared `Get-ApiKeyHttpClient` cmdlet.
- Configure and return each logger configuration received through the pipeline.

## 2.0.0-preview2 — 2026-11-03

### Features
- No new features: this release brings the module to PoShLog 3 and Serilog 4.

### Changes
- Build from the PoShLog monorepo with refreshed Serilog 4 dependencies.
- Require PowerShell 7.4+ Core.
- Require PoShLog 2.99.0 (by GUID); PoShLog 2.x users stay on 1.0.x.
- Preserve command names and parameters; use Core's shared Serilog assemblies.

### Bug fixes
- Reuse loaded dependencies at the same or a newer version; fail import with a clear module-specific error when an older version is loaded.
- Load dependencies before defining extension commands and fail import on dependency errors.
