---
name: publish-static-site-to-github-pages
description: Publish a prebuilt static site (any generator, or hand-written HTML) to GitHub Pages, on github.com OR a GitHub Enterprise Server. Probes the target for its actual capabilities with `gh api` (Actions availability, Pages source, owner type, visibility) and picks a deploy strategy from the findings instead of assuming one. Ships a canonical `scripts/deploy-site.sh` that force-pushes a gh-pages branch, derives the base path from the live Pages URL, and reconciles the served build against the pushed tip (the Enterprise auto-build trigger is unreliable). Use when a repo needs a published website and you must not hardcode assumptions about the host or its policies.
---

# Publish a static site to GitHub Pages

A capability-probing playbook. GitHub Pages behaves very differently across github.com and Enterprise Server instances, and across repo policies. **Do not assume** - probe the target, record what you find, then choose a strategy that matches. Every branch below is driven by a fact you can discover with `gh`.

This skill is generator-agnostic: it takes a directory of built static files (`dist/`, `_site/`, `public/`, hand-written HTML) and gets it served. It ships a canonical deploy script (`scripts/deploy-site.sh`) that implements the robust branch strategy end to end. For an Astro-specific companion (base-path wiring, docs sync, diagrams), see the `astro-for-github-pages` skill, which depends on this one. For a no-framework site (Markdown via pandoc + one template, or hand-written HTML), see the `hand-html-for-github-pages` skill, which also depends on this one.

## Phase 1 - Probe the environment

Run these first and write the answers down. They determine everything after.

```bash
R="<owner>/<repo>"          # e.g. octocat/site  or  bln/dotfiles

# gh defaults to the active github.com account. If the remote is an Enterprise host
# (or this machine has several gh accounts), point gh at the remote's host first, or
# every `gh api` below 404s against github.com. Honor an existing GH_HOST.
export GH_HOST="${GH_HOST:-$(git remote get-url origin | sed -E 's#^[a-z]+://##; s#^[^@]*@##; s#[:/].*$##')}"

# 1. Which host + are you authenticated?
gh auth status

# 2. Owner type - drives the base PATH.
gh api "repos/$R" --jq '.owner.type'                    # "User" or "Organization"

# 3. Visibility - private repos usually gate Pages behind SSO/auth.
gh api "repos/$R" --jq '.private'                       # true/false

# 4. Are GitHub Actions available on this repo/instance?
gh api "repos/$R/actions/permissions" --jq '.enabled'   # true/false
#    If false, test whether you can turn it on - see the trap note below.

# 5. Is Pages already enabled, and with what source?
gh api "repos/$R/pages" --jq '{build_type, source, html_url}' 2>/dev/null \
  || echo "Pages not enabled yet"
```

What each probe tells you, and what it changes downstream:

| Probe | Question | Drives |
|---|---|---|
| `gh auth status` | github.com or an Enterprise host? | URL scheme and Pages domain |
| `.owner.type` | User or Organization? | The base **path** (owner segment) |
| `.private` | Private repo? | Whether the served site is behind an SSO wall |
| `actions/permissions` `.enabled` | Are Actions usable? | Deploy strategy: Actions workflow vs `gh-pages` branch |
| `pages` `.html_url` | Is Pages on, and where does it serve? | Ground truth for the base path |

Record the host, owner type, visibility, whether Actions are usable, and the Pages state. Once Pages is enabled, its `html_url` (probe 5) is the ground truth for the base path - trust it over any formula.

> **The Actions probe has a trap.** On some Enterprise instances Actions is disabled org- or instance-wide by admins. The repo-level toggle then *silently no-ops*: a `PUT` returns success but the value stays `false`. Always write, then re-read to confirm:
>
> ```bash
> gh api -X PUT "repos/$R/actions/permissions" -F enabled=true >/dev/null 2>&1 || true
> gh api "repos/$R/actions/permissions" --jq '.enabled'   # still false -> Actions is admin-locked
> ```

## Phase 2 - Choose the deploy strategy

Pick from the probe results:

| Actions usable? | Strategy |
|---|---|
| **Yes** | GitHub Actions workflow: build in CI, deploy with `actions/upload-pages-artifact` + `actions/deploy-pages`. Requires Pages source = "GitHub Actions" (`build_type=workflow`). |
| **No** (admin-disabled, or you want zero CI) | **Local build → `gh-pages` branch.** Build locally, force-push the built output to a `gh-pages` branch that Pages serves from. No CI needed. |

The branch strategy is the robust default - it works everywhere, including instances where Actions is locked. The rest of this skill assumes it. If Actions is available and you prefer CI, use the standard Pages Actions workflow instead.

### Enable Pages

The web UI may show Pages as "disabled" even when the REST API will enable it. Prefer the API.

For a branch-served (legacy) source:

```bash
gh api -X POST "repos/$R/pages" \
  -f build_type=legacy -f 'source[branch]=gh-pages' -f 'source[path]=/' 2>/dev/null \
  || gh api -X PUT "repos/$R/pages" \
       -f build_type=legacy -f 'source[branch]=gh-pages' -f 'source[path]=/'
```

`POST` creates; if Pages is already enabled it returns 409, so fall back to `PUT` to update. For an Actions-served source (only if Actions is usable), use `-f build_type=workflow` instead.

Then confirm and capture the canonical URL:

```bash
gh api "repos/$R/pages" --jq '.html_url'
```

## Phase 3 - Compute the base path

Static sites break subtly when links and assets assume the wrong root. The path depends on host and owner type:

| Host / kind | Served at | Base path |
|---|---|---|
| github.com, project site | `https://<owner>.github.io/<repo>/` | `/<repo>/` |
| github.com, user/org root (repo named `<owner>.github.io`) | `https://<owner>.github.io/` | `/` |
| Enterprise, project site | `https://pages.<enterprise-domain>/<owner>/<repo>/` | `/<owner>/<repo>/` |

The Enterprise case includes the **owner segment** - this is the single most common Enterprise mistake. A base of `/<repo>/` (github.com style) makes every link resolve one level too shallow and 404.

**Always verify against the real `html_url` from Phase 2** rather than trusting the formula. Take its path component as the base, and feed that into your generator's config (Astro `base`, Vite `base`, `<base href>`, ...) so every asset and internal link is prefixed.

> A single-page smoke test will **not** reveal a base-path bug - it only surfaces once inter-page navigation exists. Build at least two linked pages before trusting it.

## Phase 4 - The gh-pages branch deploy

**Use the bundled script `scripts/deploy-site.sh`** - do not hand-roll this. It encodes the
lessons below, works on github.com and Enterprise, and is parameterised via env so it is
testable against a sandbox bare repo without editing. Point it at your build and run it:

```bash
# either pre-build, then let the script publish the output dir:
SITE_BUILD_DIR=dist bash scripts/deploy-site.sh

# or let the script build with the base path exported (BASE / SITE_BASE_PATH):
SITE_BUILD_DIR=dist SITE_BUILD_CMD='npm run build' bash scripts/deploy-site.sh
```

| Env var | Default | Purpose |
|---|---|---|
| `SITE_REPO_ROOT` | script's parent dir | Repo root |
| `SITE_DEPLOY_REMOTE` | `origin` | Remote to push to |
| `SITE_DEPLOY_BRANCH` | `gh-pages` | Branch Pages serves from |
| `SITE_BUILD_DIR` | `dist` | Built-output dir (`dist` / `_site` / `build` / ...) |
| `SITE_BUILD_CMD` | (none) | Optional build command, run with `BASE`/`SITE_BASE_PATH` exported |
| `SITE_PAGES_REPO` | derived from remote | `owner/repo` for the Pages API; set empty to skip enable/trigger/poll (tests) |
| `SITE_PAGES_POLL_TRIES` | `20` | Reconcile poll attempts (0 disables) |
| `SITE_PAGES_POLL_SLEEP` | `6` | Seconds between poll attempts |

What the script does, and why each step exists (these are the parts that bite if you skip them):

1. **Portable owner/repo parsing, and gh host routing.** It normalises both URL forms (`https://host/owner/repo.git`
   and `git@host:owner/repo.git`) to `owner/repo` before `basename`/`dirname`. Do **not** use a
   `sed` with non-greedy `+?` - BSD sed (macOS) rejects it and silently yields an empty repo.
   From the same URL it derives the host and exports `GH_HOST` (honoring an override), so `gh api`
   targets the remote's host: gh defaults to the active github.com account, and on an Enterprise
   remote or a multi-account machine that makes every `gh api` call 404 otherwise.
2. **Base path from the live Pages URL, guarded.** It reads `.html_url` from `gh api .../pages`
   and takes its path as the base (ground truth). A `case http*://*` guard means a 404 error
   **body** can never pollute the base path. Only before Pages exists does it fall back to a
   host-aware formula (`/owner/repo/` on Enterprise, `/repo/` on github.com).
3. **Orphan branch + `.nojekyll`.** Only the built output is committed to a fresh branch, so no
   source history or stale files leak between deploys, and Pages does not drop `_`-prefixed paths.
4. **Enable Pages if needed** (`POST .../pages` legacy source, `PUT` fallback on 409).
5. **Explicitly request a build, then RECONCILE.** This is the non-obvious one. On Enterprise the
   push auto-trigger is **intermittent** - it silently misses deploys and leaves the site serving
   the *previous* build. The script `POST`s `.../pages/builds`, then polls `.../pages/builds/latest`
   until its `.commit` equals the tip it just pushed. On non-convergence it warns loudly but does
   not fail (the branch is already correct; a re-request will catch up).

Wire it to a task in whatever runner the repo uses (mise / just / make / npm), scoped
**repo-locally** so it only resolves inside the checkout - a `deploy` task registered
in a global/user config pollutes the namespace and appears (broken) from unrelated
directories. With mise, a repo-root `mise.toml`:

```toml
#:schema https://mise.jdx.dev/schema/mise.json
# Repo-local. {{config_root}} is the repo root, so the task addresses the tree
# directly - no path boilerplate. Needs `mise trust` once (have install do it).

[tasks."site:deploy"]
run = "SITE_BUILD_DIR=dist {{config_root}}/scripts/deploy-site.sh"
```

A generator skill adds its own `build` / `preview` tasks alongside this (see the astro skill).

## Phase 5 - Verify

How you verify depends on the visibility probe from Phase 1:

| Repo | How to verify |
|---|---|
| **Public** | Fetch the `html_url` and grep for a known marker string. |
| **Private** (common on Enterprise) | The Pages host is behind SSO - a `gh` token authenticates the **API** host, not the Pages host, so `curl`/`gh` against the Pages URL return the login page (a 302 to `.../login` or `_auth_request_bounce`), not your content. See below. |

> **`"public": true` on the Pages object is misleading on Enterprise.** It does not mean anonymous
> access - a private repo's site still bounces to instance login. It can mean *any authenticated
> instance user* rather than *only users with repo access*, so if the content is confidential,
> confirm the instance's Pages access model rather than trusting the field.

For a private site you **cannot** verify served content from the CLI. Use instead:

- **Browser on the right network/VPN, logged into the instance** - the only true check.
- **Build-output inspection** as the CLI-side proxy: grep the built files in `dist/`, and/or the
  deployed branch via `gh api "repos/$R/contents/index.html?ref=gh-pages"`, to confirm structure,
  base-prefixed links, and expected content.

The script's reconcile poll already confirms the served build matches your push; branch builds can
still take a minute to propagate.
