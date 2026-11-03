# 0022 — The documentation website: Starlight built from docs/, served at poshlog.github.io from an org site repository

- **Status:** proposed
- **Date:** 2026-11-03

## Context

PoShLog's documentation is Markdown in `docs/` and in the extension READMEs. It reads well on GitHub, but there is no
site to land on from a search, no search across pages, and the pages of the extensions are spread out. Tomáš decided
on 2026-11-03:

- a documentation website on GitHub Pages at **poshlog.github.io**, without a custom domain for now;
- Starlight (Astro) as the generator, after the comparison in the CEO's research of the same day;
- no Jupyter or Polyglot notebooks: copy-paste recipes that CI tests, and VHS terminal recordings.

Constraints:

- The docs live next to the code they describe, so a pull request changes both. The Markdown keeps working on GitHub
  and in the PowerShell Gallery links that point at it.
- The TomLabs rules apply to the site: a System/Light/Dark theme that follows the OS, a layout that works at 375 px,
  the build version in the footer and the icon from `docs/assets`.
- GitHub serves `<org>.github.io` at the root only from a repository named `<org>.github.io` in that organisation.
  Pages of the `PoShLog/PoShLog` repository are served at `poshlog.github.io/PoShLog/`.
- Creating repositories, secrets and enabling Pages are outward-facing and need Tomáš's yes.

## Decision

**Source.** The site lives in `website/` (Astro + Starlight, Node 22). `docs/` stays the single source of the
content. Before every build, `website/scripts/sync-docs.mjs` copies `docs/**/*.md` and the first-party extension
READMEs into `website/src/content/docs/` (generated, not committed). It takes the title from the first `#` heading,
turns links between Markdown files into site links, points links to code and other files outside `docs/` at GitHub, and
copies `docs/assets`. The sidebar is configured in `website/astro.config.mjs` in the order of the reader's path
(getting started, concepts, cmdlets, sinks, enrichers, recipes, migration, reference). Only the landing page lives in
`website/` itself.

**Hosting.** The site is served from a repository **`PoShLog/PoShLog.github.io`**, which holds only the built
site on its `gh-pages` branch. The `PoShLog` repository builds the site in every pull request and push
(`.github/workflows/website.yml`), and on a push to `master` it pushes the build to that repository with a deploy key
(secret `SITE_DEPLOY_KEY`, write access to the site repository only). The deploy uses plain `git`, not a third-party
action. Until the repository and the key exist, the deploy job is skipped and the build still runs.
`SITE_URL` and `SITE_BASE` select the address, so serving from `poshlog.github.io/PoShLog/` is a change of two
variables.

**Look and features.**
- Starlight's theme selector (Auto, Light, Dark). Auto is the default, follows the OS live and remembers the choice.
- Starlight's responsive layout, checked at 375 px.
- Pagefind search, built at build time with no service behind it.
- `docs/assets/icon.png` as the favicon and logo.
- A footer with the PoShLog version from `src/PoShLog.psd1` and, on a build that is not from a release tag, the
  short commit (`v3.0.0-preview2+05d173b`).

**Recordings.** Terminal recordings are VHS `.tape` scripts, rendered in CI and embedded as images. They come after
the first version of the site; it ships with the tested recipes.

## Alternatives considered

- **Pages of the `PoShLog` repository (`poshlog.github.io/PoShLog/`).** No second repository and no secret: the
  official `actions/deploy-pages` works directly. It is not the address Tomáš chose, and `poshlog.github.io`
  itself would stay empty. It stays the fallback through `SITE_BASE`.
- **Site source in the `PoShLog.github.io` repository.** The docs would leave the code repository, and a change of a
  cmdlet and its page could no longer be one pull request.
- **The site repository builds itself** by checking out `PoShLog` on a schedule or a `repository_dispatch`. A dispatch
  needs a token in the `PoShLog` repository anyway, and a schedule makes the site lag behind `master`.
- **Moving the content into `website/src/content/docs/`.** Starlight's native layout, but the Markdown would stop
  reading on GitHub, and the Gallery and old links point at `docs/`.
- **Docusaurus, MkDocs Material, DocFX.** Compared in the research. MDX breaks on PowerShell syntax such as
  `<LoggerConfiguration>`, MkDocs adds a Python toolchain, and DocFX documents C# types rather than cmdlets.
- **Notebooks.** Rejected by Tomáš: the audience works in terminals and CI, and the logger is a process singleton that
  re-running cells handles badly.

## Consequences

- One pull request changes code, docs and site together. A page that is only on the site (the landing page) is the
  exception.
- Docs keep GitHub-style relative links. The sync script rewrites them, and the build fails on a link to a missing
  page, so `npm run build` is also a link check.
- Going live needs Tomáš to create `PoShLog/PoShLog.github.io`, enable Pages on its `gh-pages` branch, add the
  public half of a deploy key to it and the private half as `SITE_DEPLOY_KEY` in `PoShLog`.
- A custom domain later is a `CNAME` file in the build and a DNS record, and no change to the source.
- The site shows the docs of `master`. The published preview and `master` can differ until a version switcher is
  needed.
- Node and npm become a build dependency of the docs (not of the module). Dependencies are pinned in
  `website/package-lock.json`.
