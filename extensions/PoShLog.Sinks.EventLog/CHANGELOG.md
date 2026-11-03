# Changelog

## 2.0.0 — unreleased

### Changes
- Build from the PoShLog monorepo with refreshed Serilog 4 dependencies.
- Require PowerShell 7.4+ Core.
- Require PoShLog 2.99.0 (by GUID); PoShLog 2.x users stay on 1.0.x.
- Preserve command names and parameters; use Core's shared Serilog assemblies.

### Bug fixes
- Reuse loaded dependencies at the same or a newer version; fail import with a clear module-specific error when an older version is loaded.
- Load dependencies before defining extension commands and fail import on dependency errors.
