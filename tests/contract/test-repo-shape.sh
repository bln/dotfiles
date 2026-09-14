#!/usr/bin/env bash
# Contract test: repository has all required professional-grade files.

echo "== contract: repository shape =="

# Required documentation files
for path in \
  README.md \
  CONTRIBUTING.md \
  SECURITY.md \
  AGENTS.md \
  LICENSE \
  docs/ARCHITECTURE.md \
  docs/TESTING.md \
  docs/PACKAGE-POLICY.md \
  .github/dependabot.yml \
  .github/PULL_REQUEST_TEMPLATE.md; do

  if [ -f "$REPO/$path" ]; then
    ok "exists: $path"
  else
    bad "exists: $path" "missing required file"
  fi
done

# Every shipped script has a corresponding test file
for script in \
  scripts/check-git-identity.sh \
  scripts/check-vscode-symlink.sh \
  scripts/reset-codex.sh; do

  base="$(basename "$script" .sh)"
  test_file="$REPO/tests/unit/test-${base}.sh"
  if [ -f "$test_file" ]; then
    ok "test exists for $base"
  else
    bad "test exists for $base" "missing $test_file"
  fi
done

# Every test file follows naming convention
{
  misnamed=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    case "$base" in
      test-*) ;; # correct
      testlib.sh) ;; # library, not a test
      *) bad "naming: $base" "test file should be named test-*.sh"; misnamed=$((misnamed + 1)) ;;
    esac
  done < <(find "$REPO/tests" -name '*.sh' -not -path '*/lib/*' -not -name 'run.sh')
  [ "$misnamed" -eq 0 ] && ok "all test files follow test-*.sh convention"
}

# Public mise tasks exist
for task in bootstrap update test verify; do
  if grep -q "tasks.*$task" "$REPO/mise.toml" 2>/dev/null; then
    ok "public task: $task"
  else
    bad "public task: $task" "not found in mise.toml"
  fi
done
