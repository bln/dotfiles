#!/usr/bin/env bash
# Static validation: every configuration file parses without error.

echo "== static: config formats =="

# TOML files
{
  if command -v python3 >/dev/null 2>&1; then
    for f in "$REPO/mise.toml" "$REPO/home/.config/mise/config.toml"; do
      label="$(basename "$(dirname "$f")")/$(basename "$f") parses as TOML"
      if python3 -c "import tomllib; tomllib.load(open('$f','rb'))" 2>/dev/null; then
        ok "$label"
      else
        bad "$label" "TOML parse error in $f"
      fi
    done
  else
    ok "TOML validation (skipped - python3 not available)"
  fi
}

# Git config parses
{
  gitcfg="$REPO/home/.config/git/config"
  if git config --file "$gitcfg" --list >/dev/null 2>&1; then
    ok "git/config parses"
  else
    bad "git/config parses" "git config --list failed on $gitcfg"
  fi
}

# Shell files: syntax check with bash -n and zsh -n
{
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
}

# Neovim config loads without error (headless)
{
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
}

# YAML workflow syntax
{
  ci="$REPO/.github/workflows/ci.yml"
  if command -v python3 >/dev/null 2>&1; then
    # Check if pyyaml is available first; skip gracefully if not installed.
    if python3 -c "import yaml" 2>/dev/null; then
      if python3 -c "import yaml; yaml.safe_load(open('$ci'))" 2>/dev/null; then
        ok "ci.yml parses as YAML"
      else
        bad "ci.yml parses as YAML" "YAML parse error in $ci"
      fi
    else
      ok "ci.yml YAML check (skipped - pyyaml not installed)"
    fi
  else
    ok "ci.yml YAML check (skipped - python3 not available)"
  fi
}

# JSON templates parse after dummy placeholder substitution
{
  for tmpl in "$REPO/home/.config/mise/tasks/setup/pi-config.d/models.json.template" \
              "$REPO/home/.config/mise/tasks/setup/pi-config.d/settings.json.template"; do
    label="$(basename "$tmpl") parses as JSON after substitution"
    if command -v jq >/dev/null 2>&1; then
      rendered="$(sed 's/{{[^}]*}}/PLACEHOLDER/g' "$tmpl")"
      if printf '%s\n' "$rendered" | jq empty 2>/dev/null; then
        ok "$label"
      else
        bad "$label" "JSON parse failed after placeholder substitution"
      fi
    else
      ok "$label (skipped - jq not available)"
    fi
  done
}

# Key scripts exist and are readable
{
  for f in "$REPO/install.sh" \
           "$REPO/wipe.sh" \
           "$REPO/tests/run.sh"; do
    assert_file "$(basename "$f") exists" "$f"
  done
}

# Newline at end of file for all tracked text files (except binaries/lock)
{
  missing_nl=0
  while IFS= read -r f; do
    case "$f" in *.lock|*.png|*.jpg|*.gif|*.ico) continue ;; esac
    [ -f "$f" ] || continue
    if [ -s "$f" ] && [ "$(tail -c 1 "$f" | wc -l)" -eq 0 ]; then
      bad "trailing newline: $f" "no newline at end of file"
      missing_nl=$((missing_nl + 1))
    fi
  done < <(find "$REPO" -type f -not -path '*/.git/*' -not -name '.DS_Store' | sort)
  [ "$missing_nl" -eq 0 ] && ok "all text files end with newline"
}
