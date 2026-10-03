---
name: hand-html-for-github-pages
description: Publish a no-framework GitHub Pages site. Use when the site has no generator (not Astro/Hugo/Vite).
---

# Hand-authored HTML for GitHub Pages

The no-framework layer on top of `publish-static-site-to-github-pages`. Run that skill first: it probes the host and repo, enables Pages, picks a deploy strategy, and gives you the **base path**. This skill covers producing a correct `dist/` from Markdown + one HTML template with pandoc (the lightest "generator": no Node, no build step), plus any hand-written HTML pages. For an Astro site, use `astro-for-github-pages` instead.

## 1. One hand-authored template, driven by pandoc variables

Write **one** `template.html` (the shell: nav, theme CSS, `<head>`) and render every Markdown file through it with pandoc `--standalone --template`. Expose exactly the variables the shell needs:

- `$title$` - page title (see the `-V` trap below).
- `$base$` - URL base path prefix for nav/asset links (Section 3).
- `$has-mermaid$` - gate the Mermaid loader so only diagram pages pay for it (Section 5).

```bash
convert_doc() {  # src -> out
  local src="$1" out="$2" mermaid=""
  grep -q '```mermaid' "$src" && mermaid="-V has-mermaid=true"
  local title; title=$(grep -m1 '^# ' "$src" | sed 's/^#* *//')   # first H1; BSD-safe (no \+)
  pandoc "$src" --from gfm --to html5 --template "$TEMPLATE" --standalone \
    --syntax-highlighting=tango -V title="$title" -V base="$BASE" $mermaid -o "$out"
}
```

**Copy already-standalone HTML as-is** (e.g. a slide deck) - only run Markdown through the template.

### pandoc traps that bite

- **Titles: `-V title=...`, never `-M title=...`.** pandoc parses a `-M` value as YAML, so a title containing `": "` becomes a map and `$title$` renders **empty**. `-V` sets it as a literal string.
- **Keep hyphens hyphens: `--from gfm`, not `markdown+smart`.** Smart typography rewrites `--`/`---` into en/em dashes (which a plain-hyphen house style forbids). `gfm` leaves them alone and still handles tables and fenced code. (If you *want* smart quotes, `markdown+smart` is fine - decide deliberately.)

## 2. Build and deploy are separate concerns

Keep content rendering (this skill) filesystem-only and never touching git; the platform skill's `deploy-site.sh` owns publishing. The deploy script builds by calling your `build.sh` with `BASE`/`SITE_DIR`/`REPO_ROOT` exported, then force-pushes the output to `gh-pages`. So `build.sh` must:

- read `BASE`, `SITE_DIR` (output), `REPO_ROOT` from the env with sane defaults;
- `rm -rf "$SITE_DIR"` then rebuild (no stale files);
- exit non-zero if `index.html` is missing after the run.

That contract lets the same `build.sh` run standalone (local preview) and under `deploy-site.sh` unchanged.

## 3. Thread `base` so one build serves both offline and Pages

Take the base path from the platform skill's Phase 3 (the path component of the live Pages `html_url`) and pass it as `BASE`. Support **both modes from one build**:

| `BASE` | Links | Use |
|---|---|---|
| empty (default) | relative | local `file://`, OneDrive, offline hand-off |
| `/<owner>/<repo>/` (Pages path) | root-relative | GitHub Pages |

In the template, prefix every nav/asset href with `$base$`. In offline mode `$base$` is empty so links stay relative; in Pages mode it prefixes the served path. Verify: grep `dist/` for the expected prefix - any bare `/foo` that should be `/<base>/foo` will 404 on Pages, and a single page hides the bug (build ≥2 linked pages before trusting it).

## 4. Links: preserve repo layout, do not rewrite

The robust approach (harvested the hard way): **mirror the source directory layout under the output** (`docs/x.md` -> `docs/x.html`) and author cross-links as normal relative `.md` links. Then the only transform is `.md` -> `.html`, and relative links resolve identically in-repo, offline, and on Pages.

**Rejected - do not re-explore:** folder-aware `sed` that rewrites `../specs/x.md` into `/<base>/specs/x.html` per source folder. It is fragile (breaks on depth changes, anchors, and query strings), needs a rule per folder, and is the first thing to rot. Preserving layout deletes the whole problem. Only reach for rewriting if you are flattening a tree, and then match on the full resolved path, not the basename.

## 5. Diagrams: Mermaid from a pinned CDN, do not bundle

If a Markdown file has a ` ```mermaid ` fence, set `$has-mermaid$` (grep, Section 1) and in the template - only when that flag is set - dynamically import Mermaid from a **pinned** CDN and render:

```html
$if(has-mermaid)$
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: false, securityLevel: 'loose' });  // 'loose' if labels contain <br/>
  for (const block of document.querySelectorAll('pre.mermaid code, pre code.language-mermaid')) {
    try { const { svg } = await mermaid.render('m' + Math.random().toString(36).slice(2), block.textContent);
          /* replace block with svg in a .mermaid-wrap */ }
    catch (e) { /* surface the parse error inline; leave the source visible */ }
  }
</script>
$endif$
```

Do NOT bundle Mermaid or pre-render with a headless browser - see the astro skill's Section 3 for the full rejected-alternatives table; the reasoning is identical for the template path. If the CDN is unreachable, leave the code block in place (graceful degrade).

## 6. Repo-local runner tasks

The platform skill's Phase 4 owns `site:deploy` and explains repo-local scoping. Add the no-framework build/preview alongside it (mise example):

```toml
[tasks."site:build"]
run = "{{config_root}}/scripts/build.sh"          # BASE empty -> relative, offline-friendly

[tasks."site:preview"]                            # faithful pre-deploy check: real base + a static server
run = "BASE=/ {{config_root}}/scripts/build.sh && python3 -m http.server -d {{config_root}}/site"
```

Preview with a **root `BASE=/` over an HTTP server**, not `file://` - root-relative links only resolve under a server, and this is the closest local match to what Pages serves.

## Sequence for a new hand-HTML site

1. Run `publish-static-site-to-github-pages` Phases 1-3 (probe, enable Pages, get the base path).
2. Write `template.html` and a `build.sh` honoring the `BASE`/`SITE_DIR`/`REPO_ROOT` contract (Section 2).
3. Render Markdown through the template; copy any standalone HTML as-is; mirror repo layout (Section 4).
4. Add pinned-CDN Mermaid only if diagrams are present (Section 5).
5. Add repo-local `site:build`/`site:preview` tasks; deploy via the platform skill's Phase 4 script with `SITE_BUILD_DIR` pointing at your output dir.
6. Deploy and verify (Phase 5 of the platform skill).
