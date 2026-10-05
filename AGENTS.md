# Working in this repo

This is a personal macOS dotfiles repository.

## Source of truth

- `mise.toml` owns tools, packages, macOS preferences, dotfile declarations, and
  templates.
- `mise.lock` pins the macOS Apple Silicon tool artifacts.
- `home/` mirrors `$HOME`; mise deploys it with `symlink-each`.
- Credentials, sessions, caches, databases, and application state stay in native
  machine-local locations and are never tracked.
- Prefer native mise, Git, and macOS commands over repository wrappers.

## Change loop

1. Inspect the relevant files, callers, configuration, and current live state.
2. Make the smallest coherent change that keeps behavior visible.
3. Exercise the shipped artifact in its real setting and read the output.
4. Review the staged file list before committing and report any unchecked result.

Use Conventional Commits. Ask before pushing, deleting unrelated files, changing
skills, or making destructive cleanup. Never commit secrets or generated state.

When locking or installing tools declared by this global configuration, use
`mise lock --global` and the repository's normal mise install flow.

## XDG and native paths

`home/.zshenv` establishes the XDG configuration, cache, data, and state roots
and sets `ZDOTDIR=$HOME/.config/zsh`. Keep the managed login and interactive
startup files under `home/.config/zsh/`; the root `.zshenv` is the required
bootstrap shim.

Do not create a second configuration home, set arbitrary XDG search paths, or move
runtime data into the repository. Machine-local state belongs outside `home/`.

## Editors

- Neovim is managed by mise and configured in `home/.config/nvim/init.lua`.
- Native Vim remains configured by `home/.config/vim/vimrc` and
  `home/.config/vim/colors/`.
- `home/.config/npm/npmrc` is the npm configuration; `NPM_CONFIG_USERCONFIG`
  points npm to this path.
- `nvim` is the configured `EDITOR`, `VISUAL`, `GIT_EDITOR`, Git editor, and
  LazyGit edit preset.
- The shell may define `v='nvim'` as a convenience alias.
- Keep `vim` as the native Vim command. Do not alias or wrap `vim` to invoke
  Neovim.
- Keep both editors plugin-free unless the user explicitly chooses a different
  architecture.

The two editors share the `mini-onedark` colorscheme. Keep its semantic roles
aligned with Ghostty, Starship, fzf, eza, delta, and LazyGit rather than adding a
competing editor palette.

## Keybindings

Keybindings are a shared product decision across Vim, Neovim, Zed, and the shell:

- Preserve native Vim motions, Space behavior, and the Ctrl-W pane namespace.
- Use Space as the Vim/Neovim leader only for deliberate editor commands.
- Prefer native actions over custom mappings when the tool already expresses the
  intent.
- Use `[b` and `]b` for buffer navigation, `[e` and `]e` for visual line movement,
  and `jk` in insert mode for returning to normal mode.
- Do not recreate Zed's language-server, Tree-sitter, or multi-cursor bindings in
  Vim or Neovim.
- Keep Zed's application-specific bindings on Hyperkey; Space retains its native
  Vim meaning there.
- Check the existing keymap before adding a binding and avoid mappings that fight
  a native prefix or motion.

## Shell and terminal tools

Keep native `ls` and `cat` behavior. Convenience aliases may use eza, but `ls`
remains `command ls -G` and `cat` is not replaced. Atuin owns Ctrl-R, fzf owns
Ctrl-T and Alt-C, and native Zsh owns prefix-aware Up-arrow history search.

Themes use the One Dark palette from Ghostty's `mini-onedark` theme. Bottom and
Yazi should use terminal colors unless a deliberate native theme is added.
