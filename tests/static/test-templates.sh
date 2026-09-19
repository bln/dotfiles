#!/usr/bin/env bash
# Static: every template placeholder is one its generator actually substitutes.
#
# Each generator under tasks/setup/ renders sibling templates in
# tasks/setup/<name>.d/ and aborts if any {{ remains. If a template gains a
# {{TOKEN}} the generator never fills, `mise run setup:<name>` fails at render
# time on a fresh machine. We assert the invariant at rest: every {{TOKEN}} in
# a template must also appear as a literal {{TOKEN}} in the matching generator
# script. Tokens are derived from the generator source, so this stays correct
# as generators evolve.

echo "== static: templates =="

tokens_in() { grep -oE '\{\{[A-Za-z0-9_]+\}\}' "$1" 2>/dev/null | sort -u; }

checked=0
unknown=0
for gen in "$REPO"/tasks/setup/*; do
  [ -f "$gen" ] || continue          # skip the .d/ dirs
  name="$(basename "$gen")"
  tdir="$REPO/tasks/setup/$name.d"
  [ -d "$tdir" ] || continue
  # Tokens the generator knows how to fill (referenced as literals in its source).
  known="$(tokens_in "$gen")"
  while IFS= read -r tmpl; do
    [ -f "$tmpl" ] || continue
    checked=$((checked + 1))
    while IFS= read -r tok; do
      [ -n "$tok" ] || continue
      case "$known" in
        *"$tok"*) : ;;
        *) bad "unknown placeholder $tok" "in $(basename "$tmpl"); $name does not substitute it"; unknown=$((unknown + 1)) ;;
      esac
    done < <(tokens_in "$tmpl")
  done < <(find "$tdir" -name '*.template' 2>/dev/null)
done

if [ "$checked" -eq 0 ]; then
  bad "templates present" "no *.template found under tasks/setup/*.d"
elif [ "$unknown" -eq 0 ]; then
  ok "every template placeholder is filled by its generator ($checked templates)"
fi
