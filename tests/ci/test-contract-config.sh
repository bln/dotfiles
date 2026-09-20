#!/usr/bin/env bash
# ci: every config file PARSES in the eyes of the tool that consumes it.
#
# Scope is deliberately narrow: "will a tool choke on this file's syntax". We do
# NOT re-implement mise's semantic validation (that a tool exists, a package key
# has a valid backend, the plan resolves) - that is mise's job, gated in CI by
# the `mise config ls` and `mise bootstrap --dry-run` steps in ci.yml. Restating
# mise's rules here would be double-entry that breaks whenever the config legitimately
# evolves. See docs/TESTING.md ("Let mise validate mise's config").

echo "== ci: config parses =="

HAS_PY3=false
command -v python3 >/dev/null 2>&1 && HAS_PY3=true

# TOML: the two files mise reads. A syntax error here breaks every mise command.
for f in "$REPO/mise.toml" "$REPO/home/.config/mise/config.toml"; do
  label="$(basename "$(dirname "$f")")/$(basename "$f") parses as TOML"
  if $HAS_PY3; then
    if python3 -c "import sys,tomllib; tomllib.load(sys.stdin.buffer)" <"$f" 2>/dev/null; then
      ok "$label"
    else
      bad "$label" "TOML parse error in $f"
    fi
  else
    skip "$label (python3 not available)"
  fi
done

# Git config: git itself is the parser.
gitcfg="$REPO/home/.config/git/config"
if git config --file "$gitcfg" --list >/dev/null 2>&1; then
  ok "git/config parses"
else
  bad "git/config parses" "git config --list failed on $gitcfg"
fi

# Shell rc: zsh is the parser (bash -n for the one bash file).
if bash -n "$REPO/home/.zshenv" 2>/dev/null; then ok ".zshenv bash syntax"; else bad ".zshenv bash syntax" "bash -n failed"; fi
if command -v zsh >/dev/null 2>&1; then
  for f in "$REPO/home/.zshenv" "$REPO/home/.config/zsh/.zprofile" "$REPO/home/.config/zsh/.zshrc"; do
    label="$(basename "$f") zsh syntax"
    if zsh -n "$f" 2>/dev/null; then ok "$label"; else bad "$label" "zsh -n failed"; fi
  done
else
  skip "zsh syntax checks (zsh not available)"
fi

# Neovim: nvim is the parser (headless load of the default config).
initlua="$REPO/home/.config/nvim/init.lua"
if command -v nvim >/dev/null 2>&1; then
  if nvim --headless -u "$initlua" '+lua vim.cmd("qa!")' 2>/dev/null; then
    ok "nvim init.lua loads"
  else
    bad "nvim init.lua loads" "nvim headless load failed"
  fi
else
  skip "nvim init.lua loads (nvim not available)"
fi
