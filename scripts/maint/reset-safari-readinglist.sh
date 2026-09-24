#!/usr/bin/env bash
# Diagnose and reset a runaway Safari Reading List fetcher.
#
# Symptom this fixes: Safari's main process pegs a core (observed ~80% CPU,
# ~1%/min battery drain) because ReadingListController is stuck in a fetch
# loop - didCollectReadingListFetcherInformation -> resetForNextFetch ->
# _processItemsToFetch -> fetchInfoForItem -> initOffscreenWebView -> launch a
# WebContent process, forever. A single unfetchable item (e.g. a large PDF)
# poisons the queue, and because the item is persisted in Bookmarks.plist it
# survives every quit/restart/reset. The fix is to drop the Reading List node
# and clear its stale offline archives.
#
# Safe by default: without --apply (or APPLY=true) it only diagnoses and
# dry-runs. Backs up before mutating. Refuses to edit the plist while Safari is
# running (a live edit can corrupt bookmarks).
#
# Test seams: SAFARI_DIR (defaults to ~/Library/Safari) is honored so tests
# point it at a sandbox; SAFARI_RUNNING overrides the live pgrep check. Archive
# removal is gated by safe_under_home against $HOME. The file is sourceable
# (BASH_SOURCE guard at the bottom) so tests exercise the REAL functions, never
# a copy.
set -euo pipefail

APPLY="${APPLY:-false}"
SAFARI_DIR="${SAFARI_DIR:-$HOME/Library/Safari}"

BOOKMARKS="$SAFARI_DIR/Bookmarks.plist"
ARCHIVES="$SAFARI_DIR/ReadingListArchives"

# shellcheck source=scripts/lib/resolve-phys.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/resolve-phys.sh"

# Guard: refuse to rm -rf anything not strictly under $HOME. Resolve symlinks
# physically first so an intermediate symlink cannot escape. Mirrors the guard
# in teardown-local.sh.
safe_under_home() {
  local path="$1" phys home_phys
  [ -n "$path" ] && [ "$path" != "/" ] && [ "$path" != "$HOME" ] || return 1
  phys="$(resolve_phys "$path")"
  home_phys="$(resolve_phys "$HOME")"
  [ -n "$phys" ] && [ "$phys" != "/" ] && [ "$phys" != "$home_phys" ] || return 1
  case "$phys" in "$home_phys/"*) return 0 ;; esac
  return 1
}

# Index of the root Children entry whose Title is com.apple.ReadingList, or
# empty if absent. PlistBuddy addresses nodes by index; the Reading List is a
# top-level WebBookmarkTypeList sibling of BookmarksBar/BookmarksMenu/profiles.
readinglist_index() {
  local i title
  for i in $(seq 0 20); do
    title="$(/usr/libexec/PlistBuddy -c "Print :Children:$i:Title" "$BOOKMARKS" 2>/dev/null || true)"
    [ -z "$title" ] && continue
    if [ "$title" = "com.apple.ReadingList" ]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  return 0
}

# Print "index|url" for each Reading List item (best-effort; used for the backup
# manifest so the human can re-add links).
readinglist_items() {
  local idx="$1" j url
  [ -n "$idx" ] || return 0
  for j in $(seq 0 200); do
    url="$(/usr/libexec/PlistBuddy -c "Print :Children:$idx:Children:$j:URLString" "$BOOKMARKS" 2>/dev/null || true)"
    [ -z "$url" ] && break
    printf '%s|%s\n' "$j" "$url"
  done
}

# Test seam: SAFARI_RUNNING overrides the live check (true/false) so tests can
# exercise the --apply path without a real Safari. Unset -> real pgrep.
safari_running() {
  if [ -n "${SAFARI_RUNNING:-}" ]; then
    [ "$SAFARI_RUNNING" = true ]
    return
  fi
  pgrep -x Safari >/dev/null 2>&1
}

diagnose() {
  echo "== diagnose =="
  if [ ! -f "$BOOKMARKS" ]; then
    echo "  no Bookmarks.plist at $BOOKMARKS - nothing to inspect" >&2
    return 0
  fi
  local idx count
  idx="$(readinglist_index)"
  if [ -z "$idx" ]; then
    echo "  Reading List: none (already clear)"
  else
    count="$(readinglist_items "$idx" | wc -l | tr -d ' ')"
    echo "  Reading List: $count item(s) at Children[$idx]"
    readinglist_items "$idx" | sed 's/^\([0-9]*\)|/    [\1] /'
  fi
  if safari_running; then
    echo "  Safari: RUNNING (quit it before --apply so the plist edit is safe)"
  else
    echo "  Safari: not running"
  fi
}

backup() {
  local ts dir
  ts="$(date +%Y%m%d-%H%M%S)"
  dir="$HOME/Desktop/safari-readinglist-backup-$ts"
  mkdir -p "$dir"
  [ -f "$BOOKMARKS" ] && cp -p "$BOOKMARKS" "$dir/Bookmarks.plist"
  [ -d "$ARCHIVES" ] && cp -Rp "$ARCHIVES" "$dir/ReadingListArchives"
  # Manifest of URLs so the human can re-add links after the reset.
  local idx
  idx="$(readinglist_index)"
  readinglist_items "$idx" | sed 's/^[0-9]*|//' >"$dir/reading-list-urls.txt" 2>/dev/null || true
  printf '%s\n' "$dir"
}

reset() {
  echo "== reset =="
  if [ ! -f "$BOOKMARKS" ]; then
    echo "  no Bookmarks.plist - nothing to reset"
    return 0
  fi
  if safari_running; then
    echo "ERROR: Safari is running. Quit it first (osascript -e 'tell application \"Safari\" to quit')." >&2
    return 1
  fi

  local idx dir
  idx="$(readinglist_index)"

  if [ "$APPLY" != true ]; then
    echo "  DRY RUN: would back up Bookmarks.plist + ReadingListArchives to ~/Desktop"
    if [ -n "$idx" ]; then
      echo "  DRY RUN: would delete Reading List node Children[$idx] from $BOOKMARKS"
    else
      echo "  DRY RUN: no Reading List node to delete"
    fi
    echo "  DRY RUN: would clear archives under $ARCHIVES"
    return 0
  fi

  dir="$(backup)"
  echo "  backed up to: $dir"

  if [ -n "$idx" ]; then
    /usr/libexec/PlistBuddy -c "Delete :Children:$idx" "$BOOKMARKS"
    plutil -lint "$BOOKMARKS" >/dev/null
    echo "  deleted Reading List node Children[$idx]; plist validates OK"
  else
    echo "  no Reading List node present"
  fi

  if [ -d "$ARCHIVES" ]; then
    if safe_under_home "$ARCHIVES"; then
      # Clear contents, keep the directory (Safari recreates entries as needed).
      find "$ARCHIVES" -mindepth 1 -delete
      echo "  cleared offline archives under $ARCHIVES"
    else
      echo "WARNING: refusing to clear archives outside HOME: $ARCHIVES" >&2
    fi
  fi
}

main() {
  diagnose
  echo
  reset
  echo
  if [ "$APPLY" = true ]; then
    echo "Done. Reopen Safari and confirm CPU is near 0:"
  else
    echo "Dry run only. Re-run with --apply (Safari quit) to reset:"
    echo "  osascript -e 'tell application \"Safari\" to quit'"
    echo "  $0 --apply"
  fi
  echo "  ps -Ao pid,pcpu,comm | grep -i Safari | sort -k2 -rn | head"
}

# Execute only when run directly; sourcing (tests) just loads the functions.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  for arg in "$@"; do
    case "$arg" in
      --apply) APPLY=true ;;
      --diagnose) APPLY=false ;;
      *) printf 'unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
  done
  main
fi
