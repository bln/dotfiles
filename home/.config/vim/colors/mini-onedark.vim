" Minimal dark OneDark colorscheme for Vim.
" Palette and syntax roles are derived from:
" https://github.com/olimorris/onedarkpro.nvim/blob/main/lua/onedarkpro/themes/onedark.lua

highlight clear
if exists('syntax_on')
  syntax reset
endif
let g:colors_name = 'mini-onedark'
set background=dark

" Core syntax.
highlight Normal       guifg=#abb2bf guibg=#282c34 ctermfg=250 ctermbg=236
highlight NormalNC     guifg=#abb2bf guibg=#282c34 ctermfg=250 ctermbg=236
highlight Comment      guifg=#7f848e guibg=NONE   ctermfg=245
highlight Constant     guifg=#d19a66 guibg=NONE   ctermfg=173
highlight String       guifg=#98c379 guibg=NONE   ctermfg=149
highlight Character    guifg=#98c379 guibg=NONE   ctermfg=149
highlight Number       guifg=#d19a66 guibg=NONE   ctermfg=173
highlight Boolean      guifg=#d19a66 guibg=NONE   ctermfg=173
highlight Identifier   guifg=#e06c75 guibg=NONE   ctermfg=204
highlight Function     guifg=#61afef guibg=NONE   ctermfg=75
highlight Statement    guifg=#c678dd guibg=NONE   ctermfg=176
highlight Operator     guifg=#56b6c2 guibg=NONE   ctermfg=80
highlight Type         guifg=#e5c07b guibg=NONE   ctermfg=180
highlight StorageClass guifg=#e5c07b guibg=NONE   ctermfg=180
highlight Structure    guifg=#c678dd guibg=NONE   ctermfg=176
highlight PreProc      guifg=#e5c07b guibg=NONE   ctermfg=180
highlight Special      guifg=#61afef guibg=NONE   ctermfg=75
highlight Delimiter    guifg=#abb2bf guibg=NONE   ctermfg=250
highlight Underlined   guifg=#61afef guibg=NONE   ctermfg=75 gui=underline cterm=underline

highlight! link Conditional Statement
highlight! link Repeat Statement
highlight! link Label Statement
highlight! link Exception Statement
highlight! link Keyword Statement
highlight! link Float Number
highlight! link Typedef Type
highlight! link Include Statement
highlight! link Define Statement
highlight! link Macro Function
highlight! link PreCondit PreProc

" Messages and selections.
highlight Todo       guifg=#c678dd guibg=#282c34 ctermfg=176 ctermbg=236 gui=bold cterm=bold
highlight Error      guifg=#e06c75 guibg=#282c34 ctermfg=204 ctermbg=236 gui=bold cterm=bold
highlight ErrorMsg   guifg=#282c34 guibg=#e06c75 ctermfg=236 ctermbg=204 gui=bold cterm=bold
highlight WarningMsg guifg=#e5c07b guibg=#282c34 ctermfg=180 ctermbg=236
highlight MoreMsg    guifg=#98c379 guibg=NONE   ctermfg=149
highlight Question   guifg=#d19a66 guibg=NONE   ctermfg=173
highlight Visual     guifg=#abb2bf guibg=#414858 ctermfg=250 ctermbg=238
highlight Search     guifg=#e5c07b guibg=#414858 ctermfg=180 ctermbg=238
highlight IncSearch  guifg=#282c34 guibg=#e5c07b ctermfg=236 ctermbg=180
highlight MatchParen guifg=#56b6c2 guibg=#414858 ctermfg=80 ctermbg=238 gui=bold cterm=bold

" Editor chrome.
highlight Cursor       guifg=#282c34 guibg=#c678dd ctermfg=236 ctermbg=176
highlight CursorLine   guibg=#2d313b ctermbg=236
highlight LineNr       guifg=#495162 guibg=#282c34 ctermfg=239 ctermbg=236
highlight CursorLineNr guifg=#c678dd guibg=#2d313b ctermfg=176 ctermbg=236 gui=bold cterm=bold
highlight SignColumn   guifg=#495162 guibg=#282c34 ctermfg=239 ctermbg=236
highlight Folded       guifg=#5c6370 guibg=#2d313b ctermfg=241 ctermbg=236
highlight FoldColumn   guifg=#5c6370 guibg=#2d313b ctermfg=241 ctermbg=236
highlight VertSplit    guifg=#5c6370 guibg=#282c34 ctermfg=241 ctermbg=236
highlight NonText      guifg=#5c6370 guibg=#282c34 ctermfg=241 ctermbg=236
highlight Conceal      guifg=#61afef guibg=NONE   ctermfg=75
highlight Directory    guifg=#61afef guibg=NONE   ctermfg=75
highlight Title        guifg=#98c379 guibg=NONE   ctermfg=149

" Completion and diffs.
highlight Pmenu       guifg=#abb2bf guibg=#2d313b ctermfg=250 ctermbg=236
highlight PmenuSel    guifg=#282c34 guibg=#61afef ctermfg=236 ctermbg=75 gui=bold cterm=bold
highlight PmenuSbar   guibg=#2d313b ctermbg=236
highlight PmenuThumb  guibg=#5c6370 ctermbg=241
highlight DiffAdd     guifg=#98c379 guibg=#282c34 ctermfg=149 ctermbg=236
highlight DiffChange  guifg=#e5c07b guibg=#282c34 ctermfg=180 ctermbg=236
highlight DiffDelete  guifg=#e06c75 guibg=#282c34 ctermfg=204 ctermbg=236
highlight DiffText    guifg=#56b6c2 guibg=#282c34 ctermfg=80 ctermbg=236

" Statusline: the mode segment is intentionally the strongest accent.
highlight StatusLine     guifg=#abb2bf guibg=#2d313b ctermfg=250 ctermbg=236
highlight StatusLineNC   guifg=#5c6370 guibg=#282c34 ctermfg=241 ctermbg=236
highlight StatusLineMode guifg=#282c34 guibg=#61afef ctermfg=236 ctermbg=75 gui=bold cterm=bold
