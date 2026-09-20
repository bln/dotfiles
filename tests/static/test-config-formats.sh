#!/usr/bin/env bash
# Static validation: every configuration file parses without error.

echo "== static: config formats =="

HAS_PY3=false
command -v python3 >/dev/null 2>&1 && HAS_PY3=true

# TOML files
for f in "$REPO/mise.toml" "$REPO/home/.config/mise/config.toml"; do
  label="$(basename "$(dirname "$f")")/$(basename "$f") parses as TOML"
  if $HAS_PY3; then
    if python3 -c "import sys,tomllib; tomllib.load(sys.stdin.buffer)" < "$f" 2>/dev/null; then
      ok "$label"
    else
      bad "$label" "TOML parse error in $f"
    fi
  else
    ok "$label (skipped - python3 not available)"
  fi
done

# Git config
gitcfg="$REPO/home/.config/git/config"
if git config --file "$gitcfg" --list >/dev/null 2>&1; then
  ok "git/config parses"
else
  bad "git/config parses" "git config --list failed on $gitcfg"
fi

# Shell syntax. Listed explicitly (bash 3.2, no arrays needed for one entry).
# shellcheck disable=SC2066 # intentional single-element literal list
for f in "$REPO/home/.zshenv"; do
  label="$(basename "$f") bash syntax"
  if bash -n "$f" 2>/dev/null; then ok "$label"; else bad "$label" "bash -n failed"; fi
done

if command -v zsh >/dev/null 2>&1; then
  for f in "$REPO/home/.zshenv" \
           "$REPO/home/.config/zsh/.zprofile" \
           "$REPO/home/.config/zsh/.zshrc"; do
    label="$(basename "$f") zsh syntax"
    if zsh -n "$f" 2>/dev/null; then ok "$label"; else bad "$label" "zsh -n failed"; fi
  done
else
  ok "zsh syntax checks (skipped - zsh not available)"
fi

# Neovim config
initlua="$REPO/home/.config/nvim/init.lua"
if command -v nvim >/dev/null 2>&1; then
  if nvim --headless -u "$initlua" '+lua vim.cmd("qa!")' 2>/dev/null; then
    ok "nvim init.lua loads"
  else
    bad "nvim init.lua loads" "nvim headless load failed"
  fi
else
  ok "nvim init.lua loads (skipped - nvim not available)"
fi

# YAML workflow
ci="$REPO/.github/workflows/ci.yml"
if $HAS_PY3 && python3 -c "import yaml" 2>/dev/null; then
  if python3 -c "import sys, yaml; yaml.safe_load(open(sys.argv[1]))" "$ci" 2>/dev/null; then
    ok "ci.yml parses as YAML"
  else
    bad "ci.yml parses as YAML" "YAML parse error in $ci"
  fi
else
  ok "ci.yml YAML check (skipped - pyyaml not installed)"
fi

# Key scripts exist
for f in "$REPO/install.sh" "$REPO/tests/run.sh" \
         "$REPO/scripts/teardown-dotfiles.sh" \
         "$REPO/scripts/vscode-profiles" \
         "$REPO/scripts/teardown-local.sh"; do
  assert_file "$(basename "$f") exists" "$f"
done

# Trailing newline on all tracked text files
if $HAS_PY3; then
  missing_nl=0
  while IFS= read -r f; do
    case "$f" in *.lock|*.png|*.jpg|*.gif|*.ico) continue ;; esac
    [ -f "$f" ] || continue
    [ -s "$f" ] || continue
    if ! python3 -c "import sys; sys.exit(0 if open(sys.argv[1],'rb').read().endswith(b'\n') else 1)" "$f" 2>/dev/null; then
      bad "trailing newline: $f" "no newline at end of file"
      missing_nl=$((missing_nl + 1))
    fi
  done < <(git -C "$REPO" ls-files 2>/dev/null | sed "s|^|$REPO/|")
  [ "$missing_nl" -eq 0 ] && ok "all text files end with newline"
else
  ok "trailing newline check (skipped - python3 not available)"
fi
