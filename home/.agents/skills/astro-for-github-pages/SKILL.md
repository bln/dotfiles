---
name: astro-for-github-pages
description: Build an Astro site that publishes cleanly to GitHub Pages (github.com or Enterprise), including base-path wiring, rendering source-of-truth markdown without forking it, diagrams via CDN, and scoping build/deploy tasks to a repo-local runner. Depends on the `publish-static-site-to-github-pages` skill for the platform-level probing and deploy. Use when the site's generator is Astro.
---

# Astro for GitHub Pages

The Astro layer on top of `publish-static-site-to-github-pages`. Run that skill first: it probes the host and repo, enables Pages, picks a deploy strategy, and - critically for Astro - gives you the **base path** to configure. This skill covers what is Astro-specific.

## 1. Configure `base` and `site` from the probe

Take the base path computed in the platform skill (Phase 3 - the path component of the real Pages `html_url`) and set it in `astro.config.mjs`:

```js
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://pages.<enterprise-domain>',
  base: '/<owner>/<repo>/',
  trailingSlash: 'always',
});
```

The `site` + `base` pair is just the Pages `html_url` from Phase 3 split into
Astro's two keys: origin (scheme + host) -> `site`, path -> `base`. Phase 3 owns
the host/owner-type rules for what that path is; don't re-derive them here.

Then route **every** internal link and asset through the base:

- In `.astro`, use `import.meta.env.BASE_URL` (with a small `withBase()` helper) rather than writing absolute `/...` paths.
- Verify the build: grep `dist/` for `href="/<base>/..."`. Any bare `/foo` that should be `/<base>/foo` is a bug that will 404 on Pages.

`trailingSlash: 'always'` with the default `build.format: 'directory'` gives `docs/x/index.html` served at `/docs/x/`. Be consistent so links match files.

## 2. Render source-of-truth markdown without forking it

A common need: publish existing repo docs (README, design docs) as site pages **without** keeping a second copy that rots. The pattern is to **sync at build time** from the canonical files into Astro's content dir, which is generated and gitignored.

A `sync-docs` script copies the chosen markdown into `src/content/docs/` (gitignored), applying three transforms so repo files render well as pages:

| Transform | Why |
|---|---|
| Prepend frontmatter (`title`, `order`) | Raw repo files have none; the collection and nav need them |
| Strip the leading H1 | The page layout renders the title from frontmatter |
| Rewrite links | So they work both in-repo and on-site (see below) |

Run it as the first step of `build`:

```json
"build": "node scripts/sync-docs.mjs && astro build"
```

Prefer this over npm's `prebuild` hook, which can double-register content and emit spurious "duplicate id" warnings. Keep the sync **dumb**: an explicit list of `{ src, slug, title, order }`, no glob-and-transform framework. Gitignore `src/content/docs/`, `dist/`, and `.astro/`.

### Link rewriting (the fiddly part)

For each markdown link, resolve it to a repo-relative path (honoring `../`), then rewrite by destination:

| Link target | Rewrite to |
|---|---|
| A **synced** doc | On-site URL `${base}/docs/<slug>/#anchor` |
| Any **other** repo file (unpublished doc, script, `AGENTS.md`) | Source URL `https://<host>/<owner>/<repo>/blob/<branch>/<path>` |
| External `http(s)` link | Leave untouched |

Two rules that are easy to get wrong:

- **Include the base on synced-doc links.** Body links from markdown do NOT get Astro's base automatically the way component links do; a bare `/docs/x/` will 404.
- **Match on the full resolved repo path, not the basename.** Otherwise two different `README.md` files (repo root vs `scripts/nuke-rebuild/README.md`) collapse to the same slug.

## 3. Diagrams: load Mermaid from a pinned CDN, do not bundle

If docs contain ` ```mermaid ` fences:

- Load mermaid at runtime from a **pinned** CDN URL (`https://cdn.jsdelivr.net/npm/mermaid@<version>/dist/mermaid.esm.min.mjs`), dynamically imported **only on doc pages**. Do NOT add mermaid as a project dependency - bundling it ships megabytes of JS (cytoscape, katex, dagre) per visit.
- Astro/Shiki renders the fence as `<pre data-language="mermaid">` with highlighted spans. Read `.textContent` back for the raw source, call `mermaid.render()` (use `securityLevel: 'loose'` if labels contain HTML like `<br/>`), and surface parse errors inline instead of leaving a broken block.
- If the CDN is unreachable, leave the code block in place (graceful degrade). A pinned CDN is a reasonable dependency for a site that already pulls from package registries; add a self-hosted fallback only if the network blocks CDNs.

**Rejected alternatives** - do not re-explore:

| Alternative | Why not |
|---|---|
| Bundle full mermaid | Heavy shipped JS on every visit |
| Build-time pre-render (Puppeteer / Playwright) | Pulls in a headless browser (~150MB) and adds deploy fragility |
| Mermaid → ASCII (`mermaid-ascii`, `beautiful-mermaid`) | Browser-free, but mangle subgraphs and HTML labels; unusable for non-trivial diagrams |

## 4. Repo-local runner tasks (Astro-specific)

Scope tasks repo-locally - the platform skill's Phase 4 covers why and owns the
generic `site:deploy` task. Astro adds `dev` / `build` / `preview`, all run from
the `site/` dir:

```toml
[tasks."site:dev"]
dir = "{{config_root}}/site"
run = "npm install && npm run sync-docs && npm run dev"

[tasks."site:build"]
dir = "{{config_root}}/site"
run = "npm install && npm run build"

[tasks."site:preview"]      # build + serve the REAL dist/ - faithful pre-deploy check
dir = "{{config_root}}/site"
run = "npm install && npm run build && npm run preview"
```

`site:preview` (build, then serve `dist/`) is the faithful local check: it
matches what deploys, unlike `dev`, which uses on-the-fly transforms. If the
runner config needs trusting (mise does), have install trust it - otherwise a
fresh clone's tasks error as untrusted.

## Sequence for a new Astro site

1. Run `publish-static-site-to-github-pages` Phases 1-3 (probe, enable Pages, get the base path).
2. Scaffold Astro; set `base` / `site` / `trailingSlash` from the probe.
3. Build the pages; if publishing repo markdown, add the sync + link-rewrite step.
4. Add CDN mermaid only if diagrams are present.
5. Add repo-local runner tasks; wire deploy to the platform skill's Phase 4 deploy script (generated into the site repo) with `SITE_BUILD_DIR=dist`.
6. Deploy and browser-verify (Phase 5 of the platform skill).
