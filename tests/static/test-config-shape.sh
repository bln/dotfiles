#!/usr/bin/env bash
# Static: the mise config declares a resolvable, pinned machine.
#
# Parses home/.config/mise/config.toml and asserts the invariants that keep a
# fresh bootstrap deterministic and resolvable (FM4, version/backend drift):
#   - min_version is present (config refuses a too-old mise)
#   - lockfile = true (tool versions are pinned, not floating)
#   - every [bootstrap.packages] key carries a known backend prefix
#     (brew:, brew-cask:, ...) so mise can resolve it
#   - _.path includes ~/.local/bin (where mise shims + installed bins land)
#   - [tools] is non-empty
#
# A grep test cannot assert these structurally; we parse the real TOML.

echo "== static: config shape =="

CONFIG="$REPO/home/.config/mise/config.toml"
assert_file "config.toml exists" "$CONFIG"

if ! command -v python3 >/dev/null 2>&1; then
  skip "config shape (python3 not available to parse TOML)"
  return 0
fi

# Run the checks in one Python pass. Print "ok LABEL" or "FAIL LABEL: detail".
# Bash reads the output and dispatches to ok/bad accordingly.
# Python prints "ok LABEL" or "FAIL LABEL: DETAIL"; dispatch to testlib ok/bad.
while IFS= read -r line; do
  [ -n "$line" ] || continue
  case "$line" in
    "ok "*)
      ok "${line#ok }"
      ;;
    "FAIL "*)
      rest="${line#FAIL }"          # "LABEL: DETAIL"
      label="${rest%%: *}"
      detail="${rest#*: }"
      bad "$label" "$detail"
      ;;
  esac
done < <(python3 - "$CONFIG" <<'PY'
import sys, tomllib

cfg = tomllib.load(open(sys.argv[1], "rb"))

def ok(label):
    print(f"ok {label}")

def fail(label, detail):
    print(f"FAIL {label}: {detail}")

def check(label, cond, detail):
    ok(label) if cond else fail(label, detail)

check("min_version is declared",
      "min_version" in cfg,
      "no top-level min_version")

settings = cfg.get("settings", {})
check("lockfile pinning is enabled",
      settings.get("lockfile") is True,
      f"settings.lockfile = {settings.get('lockfile')!r}, expected true")

env = cfg.get("env", {})
path = env.get("_", {}).get("path", []) if isinstance(env.get("_"), dict) else env.get("_.path", [])
check("_.path includes ~/.local/bin",
      any(".local/bin" in str(p) for p in (path or [])),
      f"_.path = {path!r}")

KNOWN = ("brew:", "brew-cask:", "mas:", "aqua:", "cargo:", "npm:", "pipx:", "go:", "ubi:", "asdf:", "vfox:")
pkgs = cfg.get("bootstrap", {}).get("packages", {})
bad_keys = [k for k in pkgs if not any(k.startswith(p) for p in KNOWN)]
check("every package key has a known backend prefix",
      not bad_keys,
      f"unprefixed keys: {bad_keys}")

check("bootstrap.packages is non-empty", len(pkgs) > 0, "no packages declared")

tools = cfg.get("tools", {})
check("[tools] is non-empty", len(tools) > 0, "no tools declared")
PY
)
