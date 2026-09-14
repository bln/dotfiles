#!/usr/bin/env bash
# # Contract test: no direct package-manager commands in operational code.
# #
# # Resource declarations like "brew:tool" in mise config TOML are allowed.
# # Direct invocations (brew install, brew uninstall, brew bundle, etc.) in
# # scripts, tasks, and workflows are not.

# echo "== contract: package management goes through mise =="

# # Check scripts, tasks, and workflows for direct brew commands.
# # Exclude: config.toml (resource declarations), README/docs (documentation),
# # tests (they may reference patterns), and .git.
# {
#   violations=0
#   while IFS= read -r f; do
#     [ -f "$f" ] || continue
#     # Skip TOML configs, markdown, and test files
#     case "$f" in *.toml|*.md|*.lock) continue ;; */tests/*) continue ;; esac
#     if grep -nE '(^|[;&|[:space:]])brew[[:space:]]+(install|uninstall|bundle|upgrade|remove|tap)' "$f" 2>/dev/null; then
#       bad "no direct brew commands: $(basename "$f")" "direct Homebrew operation found in ${f#$REPO/}"
#       violations=$((violations + 1))
#     fi
#   done < <(find "$REPO/scripts" "$REPO/tasks" "$REPO/.github/workflows" -type f 2>/dev/null; echo "$REPO/install.sh"; echo "$REPO/wipe.sh")
#   [ "$violations" -eq 0 ] && ok "no direct Homebrew operations in scripts/tasks/workflows"
# }

# # Check for hard-coded /opt/homebrew paths in home/ configs (arch-specific).
# {
#   violations=0
#   while IFS= read -r f; do
#     [ -f "$f" ] || continue
#     if grep -n '/opt/homebrew' "$f" 2>/dev/null; then
#  #     bad "no hard-coded /opt/homebrew: $(basename "$f")" "architecture-specific path in ${f#$REPO/}"
#  #     violations=$((violations + 1))
#     fi
#   done < <(find "$REPO/home" "$REPO/scripts" "$REPO/tasks" -type f 2>/dev/null)
#   [ "$violations" -eq 0 ] && ok "no hard-coded /opt/homebrew paths"
# }
