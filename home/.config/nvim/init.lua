-- Plugin-free Neovim configuration.
-- The mini-onedark colorscheme is shared with native Vim via ~/.config/vim/colors.

-- Keep mise-managed tools available when Neovim starts outside an interactive
-- shell, such as from a GUI editor or a Git client.
local mise_shims = vim.env.HOME .. "/.local/share/mise/shims"
if not vim.env.PATH:find(mise_shims, 1, true) then
  vim.env.PATH = mise_shims .. ":" .. vim.env.PATH
end

-- ── colors ──────────────────────────────────────────────────────────────────
vim.opt.termguicolors = true
vim.opt.background = "dark"
vim.opt.runtimepath:append(vim.fn.expand("~/.config/vim"))
vim.cmd.colorscheme("mini-onedark")

-- ── options ──────────────────────────────────────────────────────────────────
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.wrap = false
vim.opt.fixendofline = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8

vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true
vim.opt.backspace = { "indent", "eol", "start" }
vim.opt.history = 10000
vim.opt.formatoptions:remove({ "c", "r", "o" })

vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.showmode = false
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.swapfile = false
vim.opt.backup = false

-- Persistent undo is state, not configuration.
vim.opt.undofile = true
local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
vim.opt.undodir = undodir

-- ── UI and completion ───────────────────────────────────────────────────────
vim.opt.wildmenu = true
vim.opt.wildmode = { "longest:full", "full" }
vim.opt.pumheight = 10
vim.opt.pumblend = 10
vim.opt.winblend = 10
vim.opt.fillchars = { eob = " " }

-- ── Netrw (built-in file explorer) ──────────────────────────────────────────
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_browse_split = 4
vim.g.netrw_altv = 1
vim.g.netrw_winsize = 25
vim.g.netrw_home = vim.fn.stdpath("state") .. "/netrw"
vim.fn.mkdir(vim.g.netrw_home, "p")

-- ── keymaps ──────────────────────────────────────────────────────────────────
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- Keep native Ctrl-W pane navigation, Vim motions, and search behavior.
map("n", "[b", "<cmd>bprevious<CR>", "Previous buffer")
map("n", "]b", "<cmd>bnext<CR>", "Next buffer")
map("v", "[e", ":<C-U>move '<-2<CR>gv=gv", "Move selection up")
map("v", "]e", ":<C-U>move '>+1<CR>gv=gv", "Move selection down")
map("i", "jk", "<Esc>", "Enter normal mode")

-- Personal Space-leader commands. Space retains its native Vim meaning in
-- Zed; Hyperkey remains Zed's application-specific leader namespace.
map("n", "<leader>e", "<cmd>Lexplore<CR>", "Open file explorer")
map("n", "<leader>w", "<cmd>write<CR>", "Save buffer")
map("n", "<leader>x", "<cmd>x<CR>", "Save and close")
map("n", "<leader>q", "<cmd>quit<CR>", "Close buffer")
map("n", "<leader>bd", "<cmd>bdelete<CR>", "Delete buffer")
map("n", "<leader>ss", "<cmd>split<CR>", "Split horizontally")
map("n", "<leader>sv", "<cmd>vsplit<CR>", "Split vertically")
map("n", "<leader>ve", "<cmd>edit $MYVIMRC<CR>", "Edit Neovim configuration")
map("n", "<leader>vr", "<cmd>source $MYVIMRC<CR>", "Reload Neovim configuration")
map("n", "<leader>rn", "<cmd>set relativenumber!<CR>", "Toggle relative line numbers")
map("x", "<leader>p", '"_dP', "Paste without replacing the register")

-- ── built-in minimal statusline ─────────────────────────────────────────────
local modes = {
  n = "NORMAL",
  no = "N-OPERATOR",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK",
  s = "SELECT",
  S = "S-LINE",
  ["\19"] = "S-BLOCK",
  i = "INSERT",
  ic = "INSERT",
  R = "REPLACE",
  Rv = "V-REPLACE",
  c = "COMMAND",
  cv = "VIM EX",
  ce = "EX",
  r = "PROMPT",
  rm = "MORE",
  ["r?"] = "CONFIRM",
  ["!"] = "SHELL",
  t = "TERMINAL",
}

_G.DotfilesStatusline = function()
  local mode = modes[vim.api.nvim_get_mode().mode] or "UNKNOWN"
  return "  %#StatusLineMode# " .. mode .. " %*  %<%f %m%r %=  %y  %l:%c %p%% "
end
vim.opt.statusline = "%!v:lua.DotfilesStatusline()"

-- ── filetype behavior ───────────────────────────────────────────────────────
local prose = vim.api.nvim_create_augroup("dotfiles_prose", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = prose,
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove({ "c", "r", "o" })
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = prose,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    if vim.bo.filetype == "markdown" then
      vim.opt_local.conceallevel = 2
      vim.opt_local.concealcursor = "nc"
    end
  end,
})

-- Restore the last cursor position on file open.
local restore = vim.api.nvim_create_augroup("dotfiles_restore", { clear = true })
vim.api.nvim_create_autocmd("BufReadPost", {
  group = restore,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Strip trailing whitespace on save, except where trailing spaces are meaningful.
local tidy = vim.api.nvim_create_augroup("dotfiles_tidy", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = tidy,
  pattern = "*",
  callback = function()
    if vim.bo.filetype == "markdown" or vim.bo.filetype == "text" then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Use the shared One Dark search accent for yank feedback.
local yank = vim.api.nvim_create_augroup("dotfiles_yank", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  group = yank,
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 200 })
  end,
})
