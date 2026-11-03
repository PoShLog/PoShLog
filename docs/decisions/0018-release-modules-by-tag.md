# 0018 — Release modules by pushing a tag

- **Status:** proposed
- **Date:** 2026-11-03

## Context

`release.yml` was started by `workflow_dispatch` only. GitHub offers a dispatch workflow only when the file exists on
the default branch, and `master` still holds the v2 history: PoShLog 3 lives on a branch until 3.0.0. The Release
workflow therefore could not be run for 3.0.0-preview2. The v2 line already releases from a tag (`release-v2.yml`,
`v2.*`), which runs the workflow file of the tagged commit.

One repository holds Core and eight extensions, each released on its own version.

## Decision

`release.yml` also runs on tag pushes and publishes one module per tag:

- `v3.*` publishes PoShLog, for example `v3.0.0-preview2`;
- `<Module>/v<version>` publishes one extension, for example `PoShLog.Sinks.Seq/v2.0.0-preview2`.

The workflow derives module and version from the tag. It refuses an unknown module, a version that differs from
`ModuleVersion` plus `Prerelease` in the committed manifest, and a module CHANGELOG without a `## <version> ` section.
The compatibility job, the Core and Pester tests and the publish with the dependency check stay as they were.
`workflow_dispatch` stays for use once the file is on the default branch.

## Alternatives considered

- **Merge v3 to master first.** It would make dispatch work, but master must keep serving v2 users until 3.0.0.
- **One tag publishes everything.** A failed extension would leave a half-released set, and extensions could not be
  released on their own.
- **Tags like `seq-v2.0.0`.** Shorter, but a second name to map; the module name in the tag is unambiguous.

## Consequences

- A release is a commit plus a tag; anyone can see from the tag list what was released from which commit.
- Push Core's tag first and extensions after Core is on the Gallery, since their dependency check queries it.
- GitHub starts no workflow when more than three tags are pushed at once, so tags are pushed one or a few at a time.
- `release-v2.yml` (`v2.*`) and `release.yml` (`v3.*`) never match the same tag.
