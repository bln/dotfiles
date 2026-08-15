#!/usr/bin/env bash
# Canonical GitHub Pages deploy: publish a built static site to a gh-pages branch
# that Pages serves from. Works on github.com AND GitHub Enterprise Server, and on
# instances where GitHub Actions is disabled (the common Enterprise case).
#
# It encodes the lessons that bite in practice:
#   - derive the base path from the LIVE Pages URL (ground truth), with a host-aware
#     fallback, and never let a 404 error body pollute it;
#   - publish an ORPHAN branch so no source history or stale files leak between deploys;
#   - add .nojekyll so Pages does not drop _-prefixed paths;
#   - EXPLICITLY request a Pages build and then RECONCILE (poll until the served build
#     matches the pushed tip) - the push auto-trigger is intermittent on Enterprise and
#     silently serves a stale build otherwise;
#   - portable owner/repo parsing (no BSD-sed non-greedy operators).
#
# Everything is overridable via env so it is testable against a sandbox bare repo
# without editing; the no-override defaults are what production uses.
#   SITE_REPO_ROOT        repo root (default: parent of this script's dir)
#   SITE_DEPLOY_REMOTE    git remote to push to (default: origin)
#   SITE_DEPLOY_BRANCH    branch Pages serves from (default: gh-pages)
#   SITE_BUILD_DIR        built-output dir under repo root (default: dist)
#   SITE_BUILD_CMD        optional build command; run in repo root with BASE and
#                         SITE_BASE_PATH exported so the generator can prefix links.
#                         If unset, SITE_BUILD_DIR is assumed already built.
#   SITE_PAGES_REPO       owner/repo for the Pages API (default: derived from remote;
#                         set empty to skip enable/trigger/poll, e.g. in tests)
#   SITE_PAGES_POLL_TRIES reconcile poll attempts (default: 20; 0 disables)
#   SITE_PAGES_POLL_SLEEP seconds between poll attempts (default: 6)
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${SITE_REPO_ROOT:-$(cd "$script_dir/.." && pwd)}"
remote="${SITE_DEPLOY_REMOTE:-origin}"
branch="${SITE_DEPLOY_BRANCH:-gh-pages}"
build_dir="${SITE_BUILD_DIR:-dist}"
poll_tries="${SITE_PAGES_POLL_TRIES:-20}"
poll_sleep="${SITE_PAGES_POLL_SLEEP:-6}"

# Resolve the push target and parse owner/repo portably. Normalise both URL forms
# (https://host/owner/repo.git and git@host:owner/repo.git) to owner/repo first, so
# basename/dirname work (BSD sed also lacks non-greedy operators).
push_url="$(cd "$repo_root" && git remote get-url "$remote" 2>/dev/null || echo "$remote")"
ownerrepo="$(printf '%s' "$push_url" | sed -E 's#^[a-z]+://##; s#^[^/@]*@##; s#^[^:/]*[:/]##')"
repo="$(basename "$ownerrepo" .git)"
owner="$(basename "$(dirname "$ownerrepo")")"
pages_repo="${SITE_PAGES_REPO-$owner/$repo}"
host="$(printf '%s' "$push_url" | sed -E 's#^[a-z]+://##; s#^[^@]*@##; s#[:/].*$##')"

have_gh() { [ -n "$pages_repo" ] && command -v gh >/dev/null 2>&1; }

# --- Base path: live Pages URL is ground truth; fall back host-aware before it exists.
case "$host" in
  github.com) [ "$repo" = "$owner.github.io" ] && base_path="/" || base_path="/$repo/" ;;
  *)          base_path="/$owner/$repo/" ;;   # Enterprise: includes the owner segment
esac
if have_gh; then
  pages_url=$(gh api "repos/$pages_repo/pages" --jq '.html_url // empty' 2>/dev/null) || pages_url=""
  case "$pages_url" in
    http://*|https://*)
      base_path=$(printf '%s' "$pages_url" | sed -E 's#^https?://[^/]+##')
      [ "${base_path%/}" = "$base_path" ] && base_path="$base_path/"
      ;;
  esac
fi
echo "==> base path: $base_path"

# --- Optional build, with the base path exported for the generator.
if [ -n "${SITE_BUILD_CMD:-}" ]; then
  echo "==> Building: $SITE_BUILD_CMD"
  ( cd "$repo_root" && BASE="$base_path" SITE_BASE_PATH="$base_path" bash -c "$SITE_BUILD_CMD" )
fi

dist="$repo_root/$build_dir"
[ -f "$dist/index.html" ] || { echo "ERROR: no $build_dir/index.html - build first or set SITE_BUILD_CMD" >&2; exit 1; }

# --- Publish an orphan branch: only built output, no history, no stale files.
echo "==> Publishing $dist -> $push_url ($branch)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cp -R "$dist/." "$work/"
touch "$work/.nojekyll"
sha="$(cd "$repo_root" && git rev-parse --short HEAD 2>/dev/null || echo unknown)"
pushed_tip="$(
  cd "$work"
  git init -q && git checkout -q -b "$branch"
  git add -A
  git -c user.name=site-deploy -c user.email=site-deploy@local commit -q -m "deploy: site @ $sha"
  git push -q --force "$push_url" "$branch"
  git rev-parse HEAD
)"

if have_gh; then
  # Enable Pages (branch/legacy source) if it is not on yet. POST creates; 409 if it
  # already exists, so fall back to PUT. Harmless when already correct.
  if [ -z "${pages_url:-}" ]; then
    echo "==> Enabling Pages ($pages_repo, branch $branch)"
    gh api -X POST "repos/$pages_repo/pages" -f build_type=legacy \
      -f "source[branch]=$branch" -f 'source[path]=/' >/dev/null 2>&1 \
      || gh api -X PUT "repos/$pages_repo/pages" -f build_type=legacy \
           -f "source[branch]=$branch" -f 'source[path]=/' >/dev/null 2>&1 \
      || echo "    WARNING: could not enable Pages via API; enable it once in Settings." >&2
  fi

  # Explicitly request a build: the push auto-trigger is intermittent on Enterprise
  # (it has silently missed deploys, leaving the site on the prior build). Best-effort.
  echo "==> Requesting Pages build ($pages_repo)"
  gh api -X POST "repos/$pages_repo/pages/builds" >/dev/null 2>&1 \
    && echo "    build queued" \
    || echo "    WARNING: could not request a build; relying on auto-build." >&2

  # Reconcile: poll until the SERVED build's commit matches the tip we pushed. Guards
  # the exact failure of a stale served build lagging an advanced branch tip. On
  # non-convergence, warn loudly but do not fail - the branch is already correct.
  if [ "$poll_tries" -gt 0 ]; then
    echo "==> Reconciling served build with pushed tip ${pushed_tip:0:8}"
    reconciled=""
    for _ in $(seq 1 "$poll_tries"); do
      built="$(gh api "repos/$pages_repo/pages/builds/latest" --jq '.commit' 2>/dev/null || echo "")"
      [ "$built" = "$pushed_tip" ] && { reconciled=1; echo "    served build matches pushed tip"; break; }
      sleep "$poll_sleep"
    done
    [ -n "$reconciled" ] || echo "    WARNING: served build (${built:0:8}) != pushed tip (${pushed_tip:0:8}); may be stale. Re-run: gh api -X POST repos/$pages_repo/pages/builds" >&2
  fi

  final_url=$(gh api "repos/$pages_repo/pages" --jq '.html_url // empty' 2>/dev/null || echo "")
  echo "==> Done. Live at ${final_url:-$base_path}"
else
  echo "==> Pushed. Enable Pages once (Settings -> Pages -> branch $branch / root), then it serves ${base_path}."
fi
