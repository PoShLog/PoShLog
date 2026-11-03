# Changelog

## 1.1.0 — unreleased

### Changes
- Build from the PoShLog monorepo with refreshed Serilog 4 dependencies.
- Require PowerShell 7.4+ Core; retain the PoShLog 2.0.0 minimum dependency by GUID.
- Preserve command names and parameters; use Core's shared Serilog assemblies.

### Bug fixes
- Load dependencies before defining extension commands and fail import on dependency errors.
