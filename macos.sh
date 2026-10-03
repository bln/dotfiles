#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  printf 'macos.sh: macOS only; skipping\n'
  exit 0
fi

# Dock
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.2

# Finder
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Keyboard and trackpad
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# General UI and system behavior
defaults write NSGlobalDomain AppleInterfaceStyleSwitchesAutomatically -bool true
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 3
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
defaults write com.apple.spaces spans-displays -bool false

# TextEdit
defaults write com.apple.TextEdit RichText -int 0 2>/dev/null || printf 'macos.sh: TextEdit preferences unavailable; skipping RichText\n' >&2
defaults write com.apple.TextEdit PlainTextEncoding -int 4 2>/dev/null || printf 'macos.sh: TextEdit preferences unavailable; skipping PlainTextEncoding\n' >&2
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4 2>/dev/null || printf 'macos.sh: TextEdit preferences unavailable; skipping PlainTextEncodingForWrite\n' >&2

# Activity Monitor
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
defaults write com.apple.ActivityMonitor ShowCategory -int 0
defaults write com.apple.ActivityMonitor SortColumn -string CPUUsage

killall Dock Finder SystemUIServer 2>/dev/null || true
