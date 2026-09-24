#!/usr/bin/env bash
# shellcheck disable=SC2154 # pass/fail counters come from the sourced testlib.sh
# maint: standalone test for scripts/maint/reset-safari-readinglist.sh.
#
# This tier is DELIBERATELY not discovered by tests/run.sh - maintenance
# scripts are run by hand, not gated by `mise run test`/`verify`/CI. So this
# file is self-contained: it sources testlib for the helpers, sets its own REPO,
# and prints its OWN summary + exit status (run.sh does that for ci/host, but it
# never sees this file). It is named *.test.sh, not test-*.sh, so even a stray
# glob pointed at tests/ cannot pull it into the suite.
#
# Run it directly:  bash tests/maint/reset-safari-readinglist.test.sh
#
# Coverage: platform-independent behavior (dry-run default, running-Safari
# refusal, arg handling, the real safe_under_home guard) runs everywhere; the
# plist round-trip needs PlistBuddy/plutil (macOS) and skips cleanly elsewhere.
#
# Seams: SAFARI_DIR points at a sandbox, SAFARI_RUNNING overrides the live
# pgrep, HOME is the sandbox so the backup lands inside it (not the real
# Desktop). The REAL safe_under_home is sourced (bottom BASH_SOURCE guard makes
# sourcing load-only), never copied.
set -euo pipefail

REPO="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export REPO
# shellcheck source=tests/lib/testlib.sh
source "$REPO/tests/lib/testlib.sh"

SCRIPT="$REPO/scripts/maint/reset-safari-readinglist.sh"

echo "== maint: reset-safari-readinglist =="

# ── safe by default: dry-run previews, exits 0, mutates nothing ──────────────
{
  home="$(sandbox)"; sdir="$home/Library/Safari"; mkdir -p "$sdir/ReadingListArchives"
  echo stale >"$sdir/ReadingListArchives/keep-in-dry-run"
  # A minimal plist (no Reading List node needed) so the dry-run reaches the
  # preview lines instead of the "no Bookmarks.plist" short-circuit.
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict/></plist>\n' >"$sdir/Bookmarks.plist"

  run_capture env HOME="$home" SAFARI_DIR="$sdir" SAFARI_RUNNING=false bash "$SCRIPT"
  assert_eq "dry-run exits 0" "0" "$RUN_STATUS"
  assert_contains "dry-run previews" "$(cat "$RUN_STDOUT")" "DRY RUN"
  assert_file "dry-run keeps archive contents" "$sdir/ReadingListArchives/keep-in-dry-run"
}

# ── --apply refuses while Safari is running (plist edit would corrupt) ────────
{
  home="$(sandbox)"; sdir="$home/Library/Safari"; mkdir -p "$sdir"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict/></plist>\n' >"$sdir/Bookmarks.plist"

  run_capture env HOME="$home" SAFARI_DIR="$sdir" SAFARI_RUNNING=true bash "$SCRIPT" --apply
  assert_eq "--apply while Safari running exits nonzero" "1" "$RUN_STATUS"
  assert_contains "explains why" "$(cat "$RUN_STDERR")" "Safari is running"
}

# ── argument handling ────────────────────────────────────────────────────────
{
  home="$(sandbox)"; sdir="$home/Library/Safari"; mkdir -p "$sdir"
  run_capture env HOME="$home" SAFARI_DIR="$sdir" SAFARI_RUNNING=false bash "$SCRIPT" --bogus
  assert_eq "unknown flag exits 2" "2" "$RUN_STATUS"
  assert_contains "names the bad flag" "$(cat "$RUN_STDERR")" "unknown argument"
}

# ── the real safe_under_home guard (sourced, not copied) ─────────────────────
{
  guard_says() { ( HOME="$1"; \
    # shellcheck source=/dev/null
    source "$SCRIPT"; safe_under_home "$2" && echo ok || echo fail ); }
  h="$(sandbox)"
  assert_eq "guard refuses /"             "fail" "$(guard_says "$h" '/')"
  assert_eq "guard refuses HOME itself"   "fail" "$(guard_says "$h" "$h")"
  assert_eq "guard refuses non-HOME path" "fail" "$(guard_says "$h" '/tmp/elsewhere')"
  assert_eq "guard accepts under HOME"    "ok"   "$(guard_says "$h" "$h/Library/Safari/ReadingListArchives")"

  escape="$(sandbox)"; mkdir -p "$escape/real"; ln -s "$escape" "$h/link-out"
  assert_eq "guard refuses symlink escaping HOME" "fail" "$(guard_says "$h" "$h/link-out/real")"
}

# ── macOS-only: the REAL plist round-trip ────────────────────────────────────
if ! command -v plutil >/dev/null 2>&1 || [ ! -x /usr/libexec/PlistBuddy ]; then
  skip "plist round-trip (plutil/PlistBuddy not available)"
else
  home="$(sandbox)"; sdir="$home/Library/Safari"; mkdir -p "$sdir/ReadingListArchives/ABC"
  bm="$sdir/Bookmarks.plist"
  echo stale >"$sdir/ReadingListArchives/ABC/page.webarchive"

  # Root Children: BookmarksBar, a Reading List node (one item), a profile -
  # the real shape the script indexes into.
  /usr/libexec/PlistBuddy \
    -c "Add :Children array" \
    -c "Add :Children:0:Title string BookmarksBar" \
    -c "Add :Children:0:WebBookmarkType string WebBookmarkTypeList" \
    -c "Add :Children:1:Title string com.apple.ReadingList" \
    -c "Add :Children:1:WebBookmarkType string WebBookmarkTypeList" \
    -c "Add :Children:1:Children array" \
    -c "Add :Children:1:Children:0:URLString string https://example.com/stuck.pdf" \
    -c "Add :Children:2:Title string Personal" \
    -c "Add :Children:2:WebBookmarkType string WebBookmarkTypeList" \
    -c "Add :WebBookmarkType string WebBookmarkTypeList" \
    "$bm" >/dev/null

  run_capture env HOME="$home" SAFARI_DIR="$sdir" SAFARI_RUNNING=false bash "$SCRIPT" --apply
  assert_eq "--apply exits 0" "0" "$RUN_STATUS"

  # Reading List node removed; siblings survive. (|| true: Print on a missing
  # index exits nonzero, which would trip set -e inside the command substitution.)
  titles="$(for i in 0 1 2 3; do /usr/libexec/PlistBuddy -c "Print :Children:$i:Title" "$bm" 2>/dev/null || true; done)"
  assert_not_contains "Reading List node deleted" "$titles" "com.apple.ReadingList"
  assert_contains "BookmarksBar survives" "$titles" "BookmarksBar"
  assert_contains "profile survives" "$titles" "Personal"

  run_capture plutil -lint "$bm"
  assert_eq "plist still validates" "0" "$RUN_STATUS"
  assert_not_exists "archive contents cleared" "$sdir/ReadingListArchives/ABC"
  assert_dir "archive dir itself kept" "$sdir/ReadingListArchives"
  bk="$(find "$home/Desktop" -maxdepth 1 -name 'safari-readinglist-backup-*' -type d | head -1)"
  assert_file "backup captured Bookmarks.plist" "$bk/Bookmarks.plist"
  assert_file "backup captured url manifest" "$bk/reading-list-urls.txt"
fi

echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
