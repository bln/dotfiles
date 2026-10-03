" ~/.vimrc
" Small, plugin-free Vim configuration.
scriptencoding utf-8

" ── options ──────────────────────────────────────────────────────────────────
syntax enable

" Match the dark terminal palette without requiring an external colorscheme.
highlight Normal       guifg=#e0e2ea guibg=#14161b ctermfg=254 ctermbg=233
highlight Comment      guifg=#9b9ea4 guibg=NONE    ctermfg=247
highlight String       guifg=#b3f6c0 guibg=NONE    ctermfg=121
highlight Identifier   guifg=#a6dbff guibg=NONE    ctermfg=153
highlight Function     guifg=#8cf8f7 guibg=NONE    ctermfg=159
highlight Statement    guifg=#e0e2ea guibg=NONE    ctermfg=254 cterm=bold gui=bold
highlight Keyword      guifg=#e0e2ea guibg=NONE    ctermfg=254 cterm=bold gui=bold
highlight Type         guifg=#e0e2ea guibg=NONE    ctermfg=254
highlight Special      guifg=#8cf8f7 guibg=NONE    ctermfg=159
highlight Constant     guifg=#e0e2ea guibg=NONE    ctermfg=254
highlight Number       guifg=#e0e2ea guibg=NONE    ctermfg=254
highlight Operator     guifg=#e0e2ea guibg=NONE    ctermfg=254
highlight Todo         guifg=#14161b guibg=#e0af68 ctermfg=233 ctermbg=179 cterm=bold gui=bold
highlight Error        guifg=#eef1f8 guibg=#590008 ctermfg=255 ctermbg=52
highlight Visual       guifg=#e0e2ea guibg=#3a3d46 ctermfg=254 ctermbg=237
highlight Search       guifg=#14161b guibg=#a6dbff ctermfg=233 ctermbg=153
highlight IncSearch   guifg=#14161b guibg=#8cf8f7 ctermfg=233 ctermbg=159
highlight Pmenu       guifg=#e0e2ea guibg=#2c2e33 ctermfg=254 ctermbg=236
highlight PmenuSel    guifg=#14161b guibg=#a6dbff ctermfg=233 ctermbg=153

highlight CursorLine  guibg=#202329 ctermbg=234
highlight LineNr      term=NONE cterm=NONE gui=NONE guifg=#4f5258 guibg=#14161b ctermfg=239 ctermbg=233
highlight CursorLineNr guifg=#a6dbff guibg=#202329 ctermfg=153 ctermbg=234 cterm=bold gui=bold
highlight SignColumn  guifg=#4f5258 guibg=#14161b ctermfg=239 ctermbg=233
highlight StatusLine  term=NONE cterm=NONE gui=NONE guifg=#e0e2ea guibg=#4f5258 ctermfg=254 ctermbg=239
highlight StatusLineNC term=NONE cterm=NONE gui=NONE guifg=#c4c6cd guibg=#2c2e33 ctermfg=250 ctermbg=236

filetype plugin indent on

set number
set relativenumber
set cursorline
if exists('+signcolumn')
  set signcolumn=yes
endif

set tabstop=2
set shiftwidth=2
set expandtab
set smartindent

set nowrap
set scrolloff=8
set sidescrolloff=8

set ignorecase
set smartcase
set nohlsearch
set incsearch
set backspace=indent,eol,start
set history=10000
set formatoptions-=c
set formatoptions-=r
set formatoptions-=o

set splitbelow
set splitright

set noswapfile
set nobackup

if has('persistent_undo')
  let s:undodir = expand('~/.vim/undo')
  if !isdirectory(s:undodir)
    call mkdir(s:undodir, 'p')
  endif
  execute 'set undodir=' . fnameescape(s:undodir) . '//'
  set undofile
endif

if exists('+termguicolors')
  set termguicolors
endif
set noshowmode
set shortmess+=F
set laststatus=2
set updatetime=250
set timeoutlen=300

if has('clipboard')
  set clipboard=unnamedplus
endif
set mouse=a

" ── UI & completion polish ──────────────────────────────────────────────────
set wildmenu
set wildmode=longest:full,full
set pumheight=10
if exists('+pumblend')
  set pumblend=10
endif
if exists('+winblend')
  set winblend=10
endif
if exists('+fillchars')
  let &fillchars = 'eob: '
endif

" ── Netrw (built-in file explorer) ──────────────────────────────────────────
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25

" ── leader key ──────────────────────────────────────────────────────────────
let mapleader = " "
let maplocalleader = " "

" ── keymaps ──────────────────────────────────────────────────────────────────
" File Explorer Toggle (built-in netrw)
nnoremap <silent> <Leader>e :Lexplore<CR>

" save and exit
nnoremap <silent> <Leader>w :write<CR>
nnoremap <silent> <Leader>x :x<CR>
nnoremap <silent> <Leader>q :quit<CR>

" buffers and windows
nnoremap <silent> <Leader>bd :bdelete<CR>
nnoremap <silent> <Leader>ss :split<CR>
nnoremap <silent> <Leader>sv :vsplit<CR>

" edit and reload this vimrc
nnoremap <silent> <Leader>ve :edit $MYVIMRC<CR>
nnoremap <silent> <Leader>vr :source $MYVIMRC<CR>

" windows
nnoremap <silent> <C-h> <C-w>h
nnoremap <silent> <C-l> <C-w>l
nnoremap <silent> <C-j> <C-w>j
nnoremap <silent> <C-k> <C-w>k

" buffers
nnoremap <silent> <S-l> :bnext<CR>
nnoremap <silent> <S-h> :bprev<CR>

" keep visual selection when indenting
xnoremap < <gv
xnoremap > >gv

" move selected lines
xnoremap J :m '>+1<CR>gv=gv
xnoremap K :m '<-2<CR>gv=gv

" center cursor after jumps
nnoremap <silent> <C-d> <C-d>zz
nnoremap <silent> <C-u> <C-u>zz
nnoremap <silent> n nzzzv
nnoremap <silent> N Nzzzv

" paste without losing register
xnoremap <silent> <Leader>p "_dP

" clear search highlight
nnoremap <silent> <Esc> :nohlsearch<CR>

" ── built-in minimal statusline ─────────────────────────────────────────────
let s:statusline_modes = {
      \ 'n': 'NORMAL',       'no': 'N-OPERATOR',
      \ 'v': 'VISUAL',       'V': 'V-LINE',
      \ "\<C-V>": 'V-BLOCK', 's': 'SELECT',
      \ 'S': 'S-LINE',       "\<C-S>": 'S-BLOCK',
      \ 'i': 'INSERT',       'ic': 'INSERT',
      \ 'R': 'REPLACE',      'Rv': 'V-REPLACE',
      \ 'c': 'COMMAND',      'cv': 'VIM EX',
      \ 'ce': 'EX',          'r': 'PROMPT',
      \ 'rm': 'MORE',        'r?': 'CONFIRM',
      \ '!': 'SHELL',        't': 'TERMINAL'
      \ }

function! DotfilesStatusline() abort
  let l:mode = get(s:statusline_modes, mode(), 'UNKNOWN')
  return '  %#StatusLineMode# ' . l:mode . ' %*  %<%f %m%r %=  %l:%c %p%% '
endfunction

highlight StatusLineMode term=NONE cterm=bold gui=bold guifg=#14161b guibg=#a6dbff ctermfg=233 ctermbg=153
set statusline=%!DotfilesStatusline()

" ── filetype tweaks & Markdown enhancements ─────────────────────────────────
augroup dotfiles_prose
  autocmd!
  autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o
  autocmd FileType markdown,text,gitcommit setlocal wrap spell spelllang=en_us
  autocmd FileType markdown setlocal conceallevel=2 concealcursor=nc
augroup END

" restore last cursor position on file open
function! DotfilesRestoreCursor() abort
  let l:line = line("'\"")
  if l:line > 0 && l:line <= line('$')
    call cursor(l:line, col("'\""))
  endif
endfunction

augroup dotfiles_restore
  autocmd!
  autocmd BufReadPost * call DotfilesRestoreCursor()
augroup END

" strip trailing whitespace on save (skip filetypes where trailing space matters)
function! DotfilesStripTrailingWhitespace() abort
  if &filetype ==# 'markdown' || &filetype ==# 'text'
    return
  endif
  let l:view = winsaveview()
  silent! keeppatterns %s/\s\+$//e
  call winrestview(l:view)
endfunction

augroup dotfiles_tidy
  autocmd!
  autocmd BufWritePre * call DotfilesStripTrailingWhitespace()
augroup END

" highlight on yank, using Vim's built-in match and timer support
if exists('##TextYankPost') && exists('*matchaddpos') && exists('*timer_start')
  function! DotfilesClearYank(timer) abort
    if exists('g:dotfiles_yank_match')
      silent! call matchdelete(g:dotfiles_yank_match, get(g:, 'dotfiles_yank_win', 0))
      unlet g:dotfiles_yank_match
      unlet! g:dotfiles_yank_win
    endif
    unlet! g:dotfiles_yank_timer
  endfunction

  function! DotfilesHighlightYank() abort
    if exists('g:dotfiles_yank_timer')
      call timer_stop(g:dotfiles_yank_timer)
      unlet g:dotfiles_yank_timer
    endif
    if exists('g:dotfiles_yank_match')
      silent! call matchdelete(g:dotfiles_yank_match, get(g:, 'dotfiles_yank_win', 0))
      unlet g:dotfiles_yank_match
      unlet! g:dotfiles_yank_win
    endif

    let l:start = getpos("'[")
    let l:end = getpos("']")
    if l:start[1] <= 0 || l:end[1] <= 0
      return
    endif

    let l:positions = []
    let l:regtype = get(v:event, 'regtype', '')
    if l:regtype ==# 'V'
      for l:line in range(l:start[1], l:end[1])
        call add(l:positions, [l:line])
      endfor
    elseif l:regtype ==# "\<C-V>"
      let l:first_col = min([l:start[2], l:end[2]])
      let l:length = abs(l:end[2] - l:start[2]) + 1
      for l:line in range(l:start[1], l:end[1])
        call add(l:positions, [l:line, l:first_col, l:length])
      endfor
    elseif l:start[1] == l:end[1]
      call add(l:positions, [l:start[1], l:start[2], max([1, l:end[2] - l:start[2] + 1])])
    else
      let l:first_length = strlen(getline(l:start[1])) - l:start[2] + 1
      call add(l:positions, [l:start[1], l:start[2], max([1, l:first_length])])
      if l:end[1] > l:start[1] + 1
        for l:line in range(l:start[1] + 1, l:end[1] - 1)
          call add(l:positions, [l:line])
        endfor
      endif
      call add(l:positions, [l:end[1], 1, max([1, l:end[2]])])
    endif

    let l:match = matchaddpos('IncSearch', l:positions)
    if l:match != -1
      let g:dotfiles_yank_match = l:match
      let g:dotfiles_yank_win = exists('*win_getid') ? win_getid() : 0
      let g:dotfiles_yank_timer = timer_start(200, 'DotfilesClearYank')
    endif
  endfunction

  augroup dotfiles_yank
    autocmd!
    autocmd TextYankPost * call DotfilesHighlightYank()
  augroup END
endif
