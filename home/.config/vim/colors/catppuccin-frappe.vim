" Minimal Catppuccin Frappé colorscheme for Vim.

highlight clear
if exists('syntax_on')
  syntax reset
endif
let g:colors_name = 'catppuccin-frappe'
set background=dark

" Core syntax.
highlight Normal       guifg=#c6d0f5 guibg=#303446 ctermfg=189 ctermbg=NONE
highlight NormalNC     guifg=#c6d0f5 guibg=#303446 ctermfg=189 ctermbg=NONE
highlight Comment      guifg=#838ba7 guibg=NONE   ctermfg=103
highlight Constant     guifg=#ef9f76 guibg=NONE   ctermfg=216
highlight String       guifg=#a6d189 guibg=NONE   ctermfg=150
highlight Character    guifg=#a6d189 guibg=NONE   ctermfg=150
highlight Number       guifg=#ef9f76 guibg=NONE   ctermfg=216
highlight Boolean      guifg=#ef9f76 guibg=NONE   ctermfg=216
highlight Identifier   guifg=#e78284 guibg=NONE   ctermfg=174
highlight Function     guifg=#8caaee guibg=NONE   ctermfg=111
highlight Statement    guifg=#ca9ee6 guibg=NONE   ctermfg=182
highlight Operator     guifg=#99d1db guibg=NONE   ctermfg=116
highlight Type         guifg=#e5c890 guibg=NONE   ctermfg=186
highlight StorageClass guifg=#e5c890 guibg=NONE   ctermfg=186
highlight Structure    guifg=#ca9ee6 guibg=NONE   ctermfg=182
highlight PreProc      guifg=#f4b8e4 guibg=NONE   ctermfg=218
highlight Special      guifg=#8caaee guibg=NONE   ctermfg=111
highlight Delimiter    guifg=#c6d0f5 guibg=NONE   ctermfg=189
highlight Underlined   guifg=#8caaee guibg=NONE   ctermfg=111 gui=underline cterm=underline

highlight! link Conditional Statement
highlight! link Repeat Statement
highlight! link Label Statement
highlight! link Exception Statement
highlight! link Keyword Statement
highlight! link Float Number
highlight! link Typedef Type
highlight! link Include PreProc
highlight! link Define PreProc
highlight! link Macro Function
highlight! link PreCondit PreProc

" Messages and selections.
highlight Todo       guifg=#303446 guibg=#ca9ee6 ctermfg=237 ctermbg=182 gui=bold cterm=bold
highlight Error      guifg=#e78284 guibg=#303446 ctermfg=174 ctermbg=237 gui=bold cterm=bold
highlight ErrorMsg   guifg=#303446 guibg=#e78284 ctermfg=237 ctermbg=174 gui=bold cterm=bold
highlight WarningMsg guifg=#ef9f76 guibg=#303446 ctermfg=216 ctermbg=237
highlight MoreMsg    guifg=#a6d189 guibg=NONE   ctermfg=150
highlight Question   guifg=#8caaee guibg=NONE   ctermfg=111
highlight Visual     guifg=#c6d0f5 guibg=#51576d ctermfg=189 ctermbg=59
highlight Search     guifg=#303446 guibg=#e5c890 ctermfg=237 ctermbg=186
highlight IncSearch  guifg=#303446 guibg=#ef9f76 ctermfg=237 ctermbg=216
highlight MatchParen guifg=#c6d0f5 guibg=#414559 ctermfg=189 ctermbg=239 gui=bold cterm=bold

" Editor chrome.
highlight Cursor       guifg=#303446 guibg=#f2d5cf ctermfg=237 ctermbg=224
highlight CursorLine   guibg=#414559 ctermbg=239
highlight LineNr       guifg=#737994 guibg=NONE   ctermfg=244
highlight CursorLineNr guifg=#babbf1 guibg=#414559 ctermfg=147 ctermbg=239 gui=bold cterm=bold
highlight SignColumn   guifg=#737994 guibg=NONE   ctermfg=244
highlight Folded       guifg=#838ba7 guibg=#414559 ctermfg=103 ctermbg=239
highlight FoldColumn   guifg=#838ba7 guibg=#414559 ctermfg=103 ctermbg=239
highlight VertSplit    guifg=#51576d guibg=NONE   ctermfg=59
highlight NonText      guifg=#737994 guibg=NONE   ctermfg=244
highlight Conceal      guifg=#8caaee guibg=NONE   ctermfg=111
highlight Directory    guifg=#8caaee guibg=NONE   ctermfg=111
highlight Title        guifg=#ca9ee6 guibg=NONE   ctermfg=182

" Completion and diffs.
highlight Pmenu       guifg=#c6d0f5 guibg=#414559 ctermfg=189 ctermbg=239
highlight PmenuSel    guifg=#c6d0f5 guibg=#51576d ctermfg=189 ctermbg=59 gui=bold cterm=bold
highlight PmenuSbar   guibg=#414559 ctermbg=239
highlight PmenuThumb  guibg=#626880 ctermbg=60
highlight DiffAdd     guifg=#a6d189 guibg=#303446 ctermfg=150 ctermbg=237
highlight DiffChange  guifg=#e5c890 guibg=#303446 ctermfg=186 ctermbg=237
highlight DiffDelete  guifg=#e78284 guibg=#303446 ctermfg=174 ctermbg=237
highlight DiffText    guifg=#81c8be guibg=#303446 ctermfg=115 ctermbg=237

" Statusline: the mode segment is intentionally the strongest accent.
highlight StatusLine     guifg=#c6d0f5 guibg=#414559 ctermfg=189 ctermbg=239
highlight StatusLineNC   guifg=#737994 guibg=#303446 ctermfg=244 ctermbg=237
highlight StatusLineMode guifg=#303446 guibg=#8caaee ctermfg=237 ctermbg=111 gui=bold cterm=bold
