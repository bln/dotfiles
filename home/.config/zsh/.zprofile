# mise: provide tool shims for non-interactive/login shells (interactive shells
# additionally run the full `mise activate` in .zshrc). Deliberate split: login
# shells and GUI-launched tools get shims here so mise-managed binaries resolve;
# interactive shells layer hooks/env on top via activate. Both running is fine -
# activate supersedes the shims for the interactive case.
command -v mise &>/dev/null && eval "$(mise activate zsh --shims)"
