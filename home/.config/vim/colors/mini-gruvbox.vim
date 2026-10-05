" Minimal dark Gruvbox colorscheme for Vim.
" Palette and syntax roles are derived from:
" https://github.com/morhetz/gruvbox/blob/master/colors/gruvbox.vim

highlight clear
if exists('syntax_on')
  syntax reset
endif
let g:colors_name = 'mini-gruvbox'
set background=dark

" Core syntax.
highlight Normal       guifg=#ebdbb2 guibg=#282828 ctermfg=223 ctermbg=235
highlight NormalNC     guifg=#ebdbb2 guibg=#282828 ctermfg=223 ctermbg=235
highlight Comment      guifg=#928374 guibg=NONE   ctermfg=245
highlight Constant     guifg=#d3869b guibg=NONE   ctermfg=175
highlight String       guifg=#b8bb26 guibg=NONE   ctermfg=142
highlight Character    guifg=#d3869b guibg=NONE   ctermfg=175
highlight Number       guifg=#d3869b guibg=NONE   ctermfg=175
highlight Boolean      guifg=#d3869b guibg=NONE   ctermfg=175
highlight Identifier   guifg=#83a598 guibg=NONE   ctermfg=109
highlight Function     guifg=#b8bb26 guibg=NONE   ctermfg=142 gui=bold cterm=bold
highlight Statement    guifg=#fb4934 guibg=NONE   ctermfg=167
highlight Operator     guifg=#ebdbb2 guibg=NONE   ctermfg=223
highlight Type         guifg=#fabd2f guibg=NONE   ctermfg=214
highlight StorageClass guifg=#fe8019 guibg=NONE   ctermfg=208
highlight Structure    guifg=#8ec07c guibg=NONE   ctermfg=108
highlight PreProc      guifg=#8ec07c guibg=NONE   ctermfg=108
highlight Special      guifg=#fe8019 guibg=NONE   ctermfg=208
highlight Delimiter    guifg=#ebdbb2 guibg=NONE   ctermfg=223
highlight Underlined   guifg=#83a598 guibg=NONE   ctermfg=109 gui=underline cterm=underline

highlight! link Conditional Statement
highlight! link Repeat Statement
highlight! link Label Statement
highlight! link Exception Statement
highlight! link Keyword Statement
highlight! link Float Number
highlight! link Typedef Type
highlight! link Include PreProc
highlight! link Define PreProc
highlight! link Macro PreProc
highlight! link PreCondit PreProc

" Messages and selections.
highlight Todo      guifg=#282828 guibg=#fabd2f ctermfg=235 ctermbg=214 gui=bold cterm=bold
highlight Error     guifg=#fb4934 guibg=#282828 ctermfg=167 ctermbg=235 gui=bold cterm=bold
highlight ErrorMsg  guifg=#282828 guibg=#fb4934 ctermfg=235 ctermbg=167 gui=bold cterm=bold
highlight WarningMsg guifg=#fabd2f guibg=#282828 ctermfg=214 ctermbg=235
highlight MoreMsg   guifg=#fabd2f guibg=NONE   ctermfg=214
highlight Question  guifg=#fe8019 guibg=NONE   ctermfg=208
highlight Visual    guifg=#ebdbb2 guibg=#665c54 ctermfg=223 ctermbg=241
highlight Search    guifg=#282828 guibg=#fabd2f ctermfg=235 ctermbg=214
highlight IncSearch guifg=#282828 guibg=#fe8019 ctermfg=235 ctermbg=208
highlight MatchParen guifg=#fabd2f guibg=#665c54 ctermfg=214 ctermbg=241 gui=bold cterm=bold

" Editor chrome.
highlight Cursor       guifg=#282828 guibg=#fabd2f ctermfg=235 ctermbg=214
highlight CursorLine   guibg=#3c3836 ctermbg=237
highlight LineNr       guifg=#7c6f64 guibg=#282828 ctermfg=243 ctermbg=235
highlight CursorLineNr guifg=#fabd2f guibg=#3c3836 ctermfg=214 ctermbg=237 gui=bold cterm=bold
highlight SignColumn   guifg=#7c6f64 guibg=#282828 ctermfg=243 ctermbg=235
highlight Folded       guifg=#928374 guibg=#3c3836 ctermfg=245 ctermbg=237
highlight FoldColumn   guifg=#928374 guibg=#3c3836 ctermfg=245 ctermbg=237
highlight VertSplit    guifg=#665c54 guibg=#282828 ctermfg=241 ctermbg=235
highlight NonText      guifg=#504945 guibg=#282828 ctermfg=239 ctermbg=235
highlight Conceal      guifg=#83a598 guibg=NONE   ctermfg=109
highlight Directory    guifg=#b8bb26 guibg=NONE   ctermfg=142 gui=bold cterm=bold
highlight Title        guifg=#b8bb26 guibg=NONE   ctermfg=142 gui=bold cterm=bold

" Completion and diffs.
highlight Pmenu       guifg=#ebdbb2 guibg=#504945 ctermfg=223 ctermbg=239
highlight PmenuSel    guifg=#504945 guibg=#83a598 ctermfg=239 ctermbg=109 gui=bold cterm=bold
highlight PmenuSbar   guibg=#504945 ctermbg=239
highlight PmenuThumb  guibg=#7c6f64 ctermbg=243
highlight DiffAdd     guifg=#b8bb26 guibg=#282828 ctermfg=142 ctermbg=235
highlight DiffChange  guifg=#8ec07c guibg=#282828 ctermfg=108 ctermbg=235
highlight DiffDelete  guifg=#fb4934 guibg=#282828 ctermfg=167 ctermbg=235
highlight DiffText    guifg=#fabd2f guibg=#282828 ctermfg=214 ctermbg=235

" Statusline: the mode segment is intentionally the strongest accent.
highlight StatusLine     guifg=#ebdbb2 guibg=#504945 ctermfg=223 ctermbg=239
highlight StatusLineNC   guifg=#928374 guibg=#3c3836 ctermfg=245 ctermbg=237
highlight StatusLineMode guifg=#282828 guibg=#fabd2f ctermfg=235 ctermbg=214 gui=bold cterm=bold
