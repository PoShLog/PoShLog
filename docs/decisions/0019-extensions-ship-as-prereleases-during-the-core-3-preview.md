# 0019 — Extensions ship as prereleases during the Core 3 preview

- **Status:** proposed
- **Date:** 2026-11-03
- **Amends:** [0012](0012-otlp-sink-design.md) (the version without a prerelease suffix)

## Context

Extensions built here require PoShLog 2.99.0 by GUID while Core 3 is a prerelease
([ADR 0017](0017-extensions-require-poshlog-2-99-while-core-is-prerelease.md)). On the Gallery that dependency can only
be met by a prerelease. ADR 0012 chose 0.1.0 without a suffix because `release.yml` could not publish prereleases;
it can now ([ADR 0018](0018-release-modules-by-tag.md)). ADR 0004 already expected the refreshed extensions to be
prereleases while Core is.

A clean-container test (PowerShell 7.4.6, PSResourceGet 1.2.0, PowerShellGet 2.2.5, local repository with Core
3.0.0-preview2, 2026-11-03):

- a **stable** extension with the 2.99.0 floor: `Install-PSResource <ext>` installs it with the Core preview, but
  `Install-Module <ext>` fails with "Unable to find dependent module(s) (PoShLog)";
- a **prerelease** extension: neither command offers it without `-Prerelease`/`-AllowPrerelease`, and
  `Install-PSResource <ext> -Prerelease` installs it with the Core preview.

Today `Install-Module PoShLog.Sinks.Seq` (and EventLog, Http, Enrichers) installs the working 1.0.x on Windows
PowerShell 5.1 and PowerShell 7. A stable 2.0.0 would become what that command picks, and it would fail.

## Decision

While Core 3 is a prerelease, every extension built here is published as a prerelease with Core's label: 2.0.0-preview2
for Seq, EventLog, Http and Enrichers, 0.1.0-preview2 for OpenTelemetry, Splunk.Hec, Syslog.Rfc5424 and Elastic. When
Core 3.0.0 is released, the extensions get stable versions in the same release.

## Alternatives considered

- **Stable 2.0.0 and 0.1.0.** `Install-Module` of the refreshed modules would stop working for everyone, including
  v2 users, and the new sinks would fail with `Install-Module`.
- **Stable only for the new sinks.** They have no 1.0.x to protect, but `Install-Module` still fails on them, and two
  rules for one preview are harder to explain than one.
- **Own labels per extension (`preview1`).** Accurate per module, but the shared label says which Core preview an
  extension was built and tested with.

## Consequences

- During the preview, `Install-Module <extension>` keeps installing the 1.0.x line, which works on v2 and v3. Preview
  extensions are installed with `Install-PSResource <extension> -Prerelease` (docs/compatibility.md).
- Every Core preview that changes an extension gives it a new label; unchanged extensions may stay on the earlier one.
- The 3.0.0 release removes the labels together with the 2.99.0 floor (ADR 0017).
