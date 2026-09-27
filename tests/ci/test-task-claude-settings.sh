#!/usr/bin/env bash
# ci: the global Claude settings task creates, merges, and safely rejects bad
# project settings through the real task file.

echo "== ci: claude settings task =="

TASK="$REPO/home/.config/mise/tasks/claude/settings"
TEMPLATES="$REPO/home/.config/mise/templates/claude/settings"

if ! command -v jq >/dev/null 2>&1; then
  skip "Claude settings task (jq not available)"
else
  project="$(sandbox)"
  git -C "$project" -c init.defaultBranch=main init -q
  mkdir -p "$project/src"

  run_task() {
    local dir="$1"
    (cd "$dir" && bash "$TASK")
  }

  run_capture run_task "$project/src"
  assert_eq "creates settings from canonical templates" "0" "$RUN_STATUS"
  assert_file "created project settings" "$project/.claude/settings.json"
  canonical="$(jq -S -s 'reduce .[] as $item ({}; . * $item)' "$TEMPLATES"/*.json)"
  generated="$(jq -S . "$project/.claude/settings.json")"
  assert_eq "generated settings contain all canonical templates" "$canonical" "$generated"

  # A project can keep unrelated settings while canonical values win on a
  # conflict. The task is run from a nested directory to exercise Git-root
  # resolution as well.
  printf '%s\n' '{"project":{"name":"fixture"},"permissions":{"allow":["Read"]},"disableWorkflows":false}' >"$project/.claude/settings.json"
  run_capture run_task "$project/src"
  assert_eq "merges an existing settings file" "0" "$RUN_STATUS"
  assert_eq "preserves unrelated project settings" "fixture" "$(jq -r '.project.name' "$project/.claude/settings.json")"
  assert_eq "preserves unrelated nested settings" "Read" "$(jq -r '.permissions.allow[0]' "$project/.claude/settings.json")"
  assert_eq "canonical value wins on conflict" "$(jq -c '.disableWorkflows' "$TEMPLATES/features.json")" "$(jq -c '.disableWorkflows' "$project/.claude/settings.json")"

  before="$(cat "$project/.claude/settings.json")"
  run_capture run_task "$project/src"
  assert_eq "second run is content-idempotent" "0" "$RUN_STATUS"
  assert_eq "second run leaves content unchanged" "$before" "$(cat "$project/.claude/settings.json")"

  printf '%s\n' '{not valid JSON' >"$project/.claude/settings.json"
  before="$(cat "$project/.claude/settings.json")"
  run_capture run_task "$project/src"
  if [ "$RUN_STATUS" -ne 0 ]; then
    ok "rejects malformed project settings"
  else
    bad "rejects malformed project settings" "task unexpectedly succeeded"
  fi
  assert_eq "malformed input is not clobbered" "$before" "$(cat "$project/.claude/settings.json")"

  if command -v mise >/dev/null 2>&1; then
    mise_project="$(sandbox)"
    mise_home="$(sandbox)"
    mise_cache="$(sandbox)"
    mkdir -p "$mise_home/.config/mise"
    git -C "$mise_project" -c init.defaultBranch=main init -q
    # Isolate the global config root while using the real config, task, and
    # template files from this checkout. This exercises mise's global task
    # dispatch without mutating the live home directory.
    ln -s "$REPO/home/.config/mise/config.toml" "$mise_home/.config/mise/config.toml"
    ln -s "$REPO/home/.config/mise/tasks" "$mise_home/.config/mise/tasks"
    ln -s "$REPO/home/.config/mise/templates" "$mise_home/.config/mise/templates"
    run_capture env \
      HOME="$mise_home" \
      XDG_CONFIG_HOME="$mise_home/.config" \
      XDG_STATE_HOME="$mise_home/.state" \
      MISE_CACHE_DIR="$mise_cache" \
      MISE_DISABLE_TOOLS=1 \
      mise -C "$mise_project" run --skip-tools --no-deps claude:settings
    assert_eq "mise discovers the task globally" "0" "$RUN_STATUS"
    assert_file "global mise invocation creates settings" "$mise_project/.claude/settings.json"
  else
    skip "global mise invocation (mise not available)"
  fi
fi
