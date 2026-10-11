# Working in this repo

Personal macOS dotfiles repository. Keep changes small, explicit, and reversible.

## Ownership

- `home/.config/mise/config.toml` owns global tools, packages, environment, macOS
  preferences, and mise settings.
- `home/.config/mise/mise.lock` pins global macOS Apple Silicon tool artifacts.
- `mise.toml` owns repository dotfile declarations, templates, and deployment policy.
- `home/` mirrors `$HOME`; mise deploys it with `symlink-each`.
- Credentials, sessions, caches, databases, generated state, and application state
  stay in native machine-local locations and are never tracked.
- Prefer native mise, Git, and macOS commands over repository wrappers.

## Change loop

1. Inspect relevant files, callers, configuration, and live state.
2. Make the smallest coherent change.
3. Exercise the shipped artifact in its real setting and read the result.
4. Review the staged file list before committing and report unchecked results.

Use Conventional Commits. Ask before deleting unrelated files, changing skills,
committing, pushing, or making destructive cleanup. Never commit secrets or
generated state. Use `mise lock --global` and the normal mise install flow for
global tools.

## Native paths

- `home/.zshenv` establishes XDG roots and `ZDOTDIR=$HOME/.config/zsh`.
- Keep login and interactive Zsh files under `home/.config/zsh/`; the root
  `.zshenv` is the required bootstrap shim.
- Keep npm configuration at `home/.config/npm/npmrc` via
  `NPM_CONFIG_USERCONFIG`.
- Do not create alternate configuration homes, arbitrary XDG paths, or repository
  runtime directories.

## Editors and keybindings

- Neovim uses `home/.config/nvim/init.lua`; native Vim uses
  `home/.config/vim/vimrc` and stays basic, plugin-free, and unthemed.
- `nvim` is the editor for the shell, Git, and mise. Keep `vim` native;
  never alias or wrap it to invoke Neovim.
- Keep both editors plugin-free. Neovim uses the `mini-onedark` palette; native
  Vim uses the terminal's default colors.
- Preserve native Vim motions, Space behavior, and the Ctrl-W pane namespace.
  Use Space as leader only for deliberate editor commands.
- Keep `[b`/`]b`, `[e`/`]e`, and insert-mode `jk` bindings. Do not copy Zed's
  language-server, Tree-sitter, or multi-cursor bindings into Vim or Neovim.
- Keep Zed-specific bindings on Hyperkey; Space retains its native Vim meaning.

## Shell and terminal

- Keep native `ls` and `cat`; `ls` remains `command ls -G` and `cat` is not replaced.
- Atuin owns Ctrl-R, fzf owns Ctrl-T and Alt-C, and native Zsh owns prefix-aware
  Up-arrow history search.
- Keep Bottom and Yazi on terminal colors unless a deliberate native theme is added.
