# 0017 — Extensions require PoShLog 2.99.0 while Core 3 is a prerelease

- **Status:** accepted (Tomáš, 2026-11-03)
- **Date:** 2026-11-03
- **Amends:** [0004](0004-refreshed-extensions-require-poshlog-3.md) (the version floor only)

## Context

ADR 0004 has every extension built here declare `RequiredModules` PoShLog `3.0.0` by GUID. Core is published as
`3.0.0-preview1` and the next release is `3.0.0-preview2`. Package managers order versions by SemVer, where
`3.0.0-preview2` is lower than `3.0.0`, so nothing on the Gallery satisfies the floor until 3.0.0 is stable.

A clean-container test (PowerShell 7.4.6, local file repository, 2026-11-03) confirmed it:

- `Publish-PSResource` refuses an extension whose floor is 3.0.0: the dependency is not in the repository.
- Published with the check skipped, the extension cannot be installed by `Install-PSResource -Prerelease`
  (PSResourceGet 1.2.0) or `Install-Module -AllowPrerelease` (PowerShellGet 2.2.5), even with Core 3.0.0-preview2
  already installed.
- With the floor at **2.99.0**, PSResourceGet 1.2.0 publishes the extensions with its dependency check, and
  `Install-PSResource <extension> -Prerelease` installs the extension together with Core 3.0.0-preview2. Import
  and logging work. PowerShellGet 2.2.5 still cannot resolve a prerelease dependency.

`Import-Module` compares `ModuleVersion` without the prerelease label, so 3.0.0-preview2 loads as 3.0.0 and meets
either floor. No PoShLog 2.x release is or will be numbered 2.99.

## Decision

While Core 3 is a prerelease, extensions built here declare `RequiredModules` PoShLog **2.99.0** by GUID. This keeps
every PoShLog 2.x away (the v2 line ends below 2.99) and lets package managers resolve the Core prerelease. The
release commit of PoShLog 3.0.0 sets the floor back to 3.0.0 in the same commit.

Extensions are published and installed during the preview with PSResourceGet: `Install-PSResource -Prerelease`.
`Install-Module` is documented for Core only.

## Alternatives considered

- **Keep 3.0.0 and publish no extension until Core 3.0.0 is stable.** Correct, but the preview could only be tried
  with the built-in sinks, and the new sinks (OpenTelemetry, Splunk HEC, Syslog) would get no preview feedback.
- **No version in `RequiredModules` (name and GUID only).** Package managers then install the newest stable Core,
  PoShLog 2.2.0, next to the preview, and a v2-only machine would accept an extension that cannot run there.
- **Number the Core previews 2.99.x.** Wrong signal to users and the Gallery history; 3.0.0-preview1 is already out.

## Consequences

- Preview users can install any extension with one command: `Install-PSResource <extension> -Prerelease`.
- `Install-Module -AllowPrerelease` does not work for extensions during the preview. The documentation says so and
  gives the PSResourceGet command.
- The 3.0.0 release commit has one more step: floor back to 3.0.0 (manifests, docs, this ADR superseded or closed).
- The test was run against a local file repository, not the Gallery. The first preview2 publish confirms it on the
  Gallery before the documentation calls it verified there.
