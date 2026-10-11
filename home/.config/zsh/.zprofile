# Make standalone mise and Homebrew available before .zshrc activates mise.
# Mise then places its managed tools and shims ahead of these inherited paths.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
