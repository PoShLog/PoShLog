# Changelog

## Unreleased

### Features
- No new features.

### Changes
- Requires PowerShell 7.6 or newer and is built for .NET 10 (ADR 0033). This is a breaking change on PowerShell 7.4 and 7.5: stay on the previous version there, or on PoShLog 2.x with the 1.0.x extensions.

### Bug fixes
- None.

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
