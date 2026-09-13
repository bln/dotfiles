#!/usr/bin/env bash
# Cross-file consistency: commands, fonts, themes, and packages reference each other correctly.

echo "== static: cross-file references =="

CONFIG="$REPO/home/.config/mise/config.toml"
ZSHRC="$REPO/home/.config/zsh/.zshrc"
VSCODE="$REPO/home/.config/vscode/settings.json"
BREWFILE="$REPO/home/.config/homebrew/Brewfile"

# Helper: check if a command is declared as a mise tool or bootstrap package.
# Returns 0 if found, 1 if not.
is_declared() {
  local cmd="$1"
  grep -qE "(\"brew:$cmd\"|\"brew-cask:$cmd\"|^$cmd =)" "$CONFIG" 2>/dev/null
}

# Commands referenced by .zshrc that must have a provider.
# Two parallel arrays (bash 3.2 safe - no declare -A).
# Kinds: "declared" = must be in config.toml [tools]/[bootstrap.packages]
#        "self"     = installed by install.sh itself (not a config entry)
#        "optional" = guarded by `command -v` in zshrc; should still be declared
_cmds=(mise starship zoxide fzf bat eza fd zsh-autosuggestions zsh-syntax-highlighting)
_kinds=(self declared declared declared declared declared optional declared declared)

_i=0
for cmd in "${_cmds[@]}"; do
  kind="${_kinds[$_i]}"
  _i=$((_i + 1))
  case "$kind" in
    declared|optional)
      if is_declared "$cmd"; then
        ok "$cmd declared in config"
      else
        if [ "$kind" = "declared" ]; then
          bad "$cmd declared in config" "$cmd used in .zshrc but not in config.toml [tools] or [bootstrap.packages]"
        else
          bad "$cmd declared in config (optional)" "$cmd used in .zshrc (guarded) but has no package declaration"
        fi
      fi
      ;;
    self)
      # mise manages itself - installed by install.sh, not a config.toml entry
      ok "$cmd (managed by install.sh, not a config entry)"
      ;;
  esac
done
unset _cmds _kinds _i

# Font references: VS Code font family must be in a cask declaration
{
  if command -v python3 >/dev/null 2>&1; then
    vscode_font="$(python3 -c "
import json, re
raw = open('$VSCODE').read()
raw = re.sub(r'//.*', '', raw)
data = json.loads(raw)
print(data.get('editor.fontFamily', ''))
" 2>/dev/null)"
    case "$vscode_font" in
      *JetBrainsMono*|*JetBrains\ Mono*)
        if grep -q "font-jetbrains-mono" "$CONFIG" 2>/dev/null; then
          ok "VS Code font (JetBrains Mono) has cask declaration"
        else
          bad "VS Code font declaration" "JetBrains Mono referenced but no cask found"
        fi
        ;;
      "")
        ok "VS Code font check (no custom font set)"
        ;;
      *)
        ok "VS Code font check ($vscode_font - not validated)"
        ;;
    esac
  else
    ok "VS Code font check (skipped - python3 not available)"
  fi
}

# VS Code theme references: declared themes must have matching extensions
{
  if command -v python3 >/dev/null 2>&1; then
    themes="$(python3 -c "
import json, re
raw = open('$VSCODE').read()
raw = re.sub(r'//.*', '', raw)
data = json.loads(raw)
for k in ['workbench.preferredDarkColorTheme', 'workbench.preferredLightColorTheme', 'workbench.colorTheme']:
    v = data.get(k, '')
    if v: print(v)
" 2>/dev/null)"
    while IFS= read -r theme; do
      [ -z "$theme" ] && continue
      case "$theme" in
        *"One Dark Pro"*)
          if grep -q "zhuangtongfa.material-theme" "$BREWFILE" 2>/dev/null; then
            ok "theme '$theme' has extension in Brewfile"
          else
            bad "theme '$theme' extension" "no matching extension found in Brewfile"
          fi
          ;;
        *)
          ok "theme '$theme' (not validated - may be built-in)"
          ;;
      esac
    done <<< "$themes"
  else
    ok "VS Code theme checks (skipped - python3 not available)"
  fi
}

# Template integrity: every template contains expected placeholders.
{
  cfg_tmpl="$REPO/home/.config/mise/tasks/setup/git-identity.d/config.local.template"
  play_tmpl="$REPO/home/.config/mise/tasks/setup/git-identity.d/identity-play.template"
  models_tmpl="$REPO/home/.config/mise/tasks/setup/pi-config.d/models.json.template"

  for marker in "{{WORK_NAME}}" "{{WORK_EMAIL}}"; do
    assert_contains "config.local.template has $marker" "$(cat "$cfg_tmpl")" "$marker"
  done
  for marker in "{{PLAY_NAME}}" "{{PLAY_EMAIL}}"; do
    assert_contains "identity-play.template has $marker" "$(cat "$play_tmpl")" "$marker"
  done
  assert_contains "models.json.template has PI_PROXY_API_KEY" "$(cat "$models_tmpl")" "{{PI_PROXY_API_KEY}}"
}

# Dotfile source integrity: every [dotfiles] entry's source file exists.
{
  dotfiles_root="$REPO/home"
  fail_count=0
  while IFS= read -r line; do
    target="$(printf '%s' "$line" | sed -E 's/^"([^"]+)".*/\1/')"
    [ -z "$target" ] && continue

    if printf '%s' "$line" | grep -q 'source'; then
      src="$(printf '%s' "$line" | sed -E 's/.*source = "([^"]+)".*/\1/')"
      src="${src/#\~\/dotfiles/$REPO}"
    else
      rel="${target/#\~\//}"
      src="$dotfiles_root/$rel"
    fi

    if [ -e "$src" ]; then
      ok "dotfile source exists: $(basename "$src")"
    else
      bad "dotfile source exists: $(basename "$src")" "missing: $src (for target $target)"
      fail_count=$((fail_count + 1))
    fi
  done < <(grep -E '^\s*"~' "$CONFIG" | grep -v '^#')
  [ "$fail_count" -eq 0 ] || true
}
