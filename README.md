# dotfiles

Personal macOS workstation configuration for Apple Silicon. The `home/` directory mirrors `$HOME`.

## Install

```sh
git clone https://github.com/bln/dotfiles.git ~/dotfiles
cd ~/dotfiles

curl -fsSL --proto '=https' https://mise.run | sh
MISE_CONFIG_DIR="$PWD/home/.config/mise" "$HOME/.local/bin/mise" bootstrap --yes --force-dotfiles
```

## Repository layout

```text
dotfiles/
├── .github/                                  GitHub project automation
│   └── workflows/                            CI workflows
├── home/                                     Files deployed into $HOME
│   ├── .agents/                              Shared coding-agent instructions
│   ├── .config/                              XDG application configuration
│   │   ├── ghostty/                          Ghostty terminal settings
│   │   │   └── themes/                       Ghostty color themes
│   │   ├── git/                              Git defaults and ignore rules
│   │   ├── mise/                             Global mise settings and tool lockfile
│   │   ├── npm/                              npm install policy
│   │   ├── uv/                               uv package policy
│   │   ├── vim/                              Vim configuration
│   │   │   └── colors/                       Vim color schemes
│   │   ├── zed/                              Zed settings and keybindings
│   │   ├── zsh/                              Zsh startup files
│   │   └── starship.toml                     Starship prompt settings
│   ├── Library/                              macOS user application settings
│   │   └── Application Support/              macOS application support files
│   │       └── Code/                         VS Code configuration
│   │           └── User/                     VS Code user settings and keybindings
│   └── .zshenv                               XDG paths and shell environment setup
├── patches/                                  Settings merged into existing app configs
│   ├── .claude/                              Claude Code settings patch
│   ├── .pi/                                  Pi settings patches
│   │   └── agent/                            Pi agent settings patch
│   └── rtk/                                  RTK settings patch
├── .gitignore                                Local and generated files to ignore
├── AGENTS.md                                 Repository working agreement
├── LICENSE                                   MIT license
├── mise.toml                                 Dotfile groups and repository tasks
├── README.md                                 Setup and repository guide
└── uninstall.sh                              Mise-managed setup removal
```

## Uninstall

```sh
./uninstall.sh --yes
```

## CI

GitHub Actions runs on macOS 26. It checks shell syntax, mise configuration and dotfile deployment, and Git whitespace.
