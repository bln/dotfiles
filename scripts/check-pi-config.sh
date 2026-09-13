#!/usr/bin/env bash
# Assert pi agent config files are present, valid, and correctly permissioned.
set -euo pipefail

# Seam: PI_AGENT_DIR overridable so tests can point at a sandbox.
agent_dir="${PI_AGENT_DIR:-$HOME/.pi/agent}"

errors=0
warn_count=0

check_file() {
  local file="$1" label="$2"
  if [ ! -f "$file" ]; then
    echo "ERROR: $file missing - run 'mise run setup:pi-config'" >&2
    errors=$((errors + 1))
    return 1
  fi

  # Check permissions (mode 600)
  local mode
  mode="$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file")"
  if [ "$mode" != "600" ]; then
    echo "WARNING: $label is mode $mode, expected 600" >&2
    warn_count=$((warn_count + 1))
  fi

  # Check no unfilled template placeholders
  if grep -q '[{][{]' "$file" 2>/dev/null; then
    echo "ERROR: $label contains unfilled template placeholders" >&2
    errors=$((errors + 1))
    return 1
  fi

  # Validate JSON
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$file" 2>/dev/null; then
      echo "ERROR: $label is not valid JSON" >&2
      errors=$((errors + 1))
      return 1
    fi
  elif command -v jq >/dev/null 2>&1; then
    if ! jq empty "$file" 2>/dev/null; then
      echo "ERROR: $label is not valid JSON" >&2
      errors=$((errors + 1))
      return 1
    fi
  fi

  return 0
}

check_file "$agent_dir/models.json" "models.json"
check_file "$agent_dir/settings.json" "settings.json"

if [ "$errors" -gt 0 ]; then
  exit 1
fi

if [ "$warn_count" -gt 0 ]; then
  echo "OK: pi config present and valid ($warn_count warning(s))."
else
  echo "OK: pi config present and valid."
fi
