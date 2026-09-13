#!/usr/bin/env bash
# Tests for home/.config/mise/tasks/setup/pi-config

echo "== pi-config =="

PI_CONFIG="$REPO/tasks/setup/pi-config"

# Happy path: secret from env, templates render into $PI_AGENT_DIR, mode 600,
# and the key is substituted (no placeholder left behind).
{
  agent="$(sandbox)/agent"
  out="$(PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="sekret-123" bash "$PI_CONFIG" </dev/null 2>&1)"
  assert_file "models.json written"   "$agent/models.json"
  assert_file "settings.json written" "$agent/settings.json"
  assert_contains "api key substituted" "$(cat "$agent/models.json")" "sekret-123"
  assert_no_placeholder "no placeholder remains" "$(cat "$agent/models.json")"
  assert_mode "models.json is chmod 600" "$agent/models.json" "600"
  assert_mode "settings.json is chmod 600" "$agent/settings.json" "600"
  assert_json "models.json is valid JSON" "$agent/models.json"
  assert_json "settings.json is valid JSON" "$agent/settings.json"
}

# Idempotency: without --force, an existing file is skipped, not overwritten.
{
  agent="$(sandbox)/agent"
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="first" bash "$PI_CONFIG" </dev/null >/dev/null 2>&1
  out="$(PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="second" bash "$PI_CONFIG" </dev/null 2>&1)"
  assert_contains "skips existing without --force" "$out" "skip:"
  assert_contains "original key preserved" "$(cat "$agent/models.json")" "first"
}

# --force overwrites and re-renders with the new secret.
{
  agent="$(sandbox)/agent"
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="first" bash "$PI_CONFIG" </dev/null >/dev/null 2>&1
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY="second" USAGE_FORCE=true bash "$PI_CONFIG" </dev/null >/dev/null 2>&1
  assert_contains "--force re-renders with new key" "$(cat "$agent/models.json")" "second"
}

# Note: unknown-argument validation is now handled by mise's #USAGE machinery
# when the task is run via `mise run setup:pi-config`. Direct bash invocation
# no longer validates flags; that behaviour moved to the mise task layer.

# Edge case: API key with shell metacharacters ($, backtick, &).
# These are shell-special but JSON-safe; the substitution must preserve them literally.
# We intentionally do NOT include " (double-quote) here: that would produce invalid JSON
# and correctly cause validate_json to reject it - that path is a separate concern.
{
  agent="$(sandbox)/agent"
  PI_AGENT_DIR="$agent" PI_PROXY_API_KEY='sk-test&$`key' bash "$PI_CONFIG" </dev/null >/dev/null 2>&1
  assert_contains "metachar key preserved literally" "$(cat "$agent/models.json")" 'sk-test&$`key'
}
