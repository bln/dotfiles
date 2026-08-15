-- Prepend mise shims to PATH so LSPs/formatters/tools resolve mise-managed
-- binaries even when nvim is launched from a GUI context (which doesn't source
-- .zprofile). See https://mise.jdx.dev/ide-integration.html
vim.env.PATH = vim.env.HOME .. "/.local/share/mise/shims:" .. vim.env.PATH

-- ── options ──────────────────────────────────────────────────────────────────
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.cursorline     = true
vim.opt.signcolumn     = "yes"

vim.opt.tabstop        = 2
vim.opt.shiftwidth     = 2
vim.opt.expandtab      = true
vim.opt.smartindent    = true

vim.opt.wrap           = false
vim.opt.scrolloff      = 8
vim.opt.sidescrolloff  = 8

vim.opt.ignorecase     = true
vim.opt.smartcase      = true
vim.opt.hlsearch       = false
vim.opt.incsearch      = true

vim.opt.splitbelow     = true
vim.opt.splitright     = true

vim.opt.undofile       = true
vim.opt.swapfile       = false
vim.opt.backup         = false

vim.opt.termguicolors  = true
vim.opt.showmode       = false   -- mode shown by statusline instead
vim.opt.updatetime     = 250
vim.opt.timeoutlen     = 300

vim.opt.clipboard      = "unnamedplus"   -- sync with system clipboard
vim.opt.mouse          = "a"

-- ── UI & Completion Polish (Plugin-Free) ────────────────────────────────────
vim.opt.wildmode       = "longest:full,full" -- Command completion menu
vim.opt.pumheight      = 10                  -- Popup menu height
vim.opt.pumblend       = 10                  -- Pseudo-transparency for completion
vim.opt.winblend       = 10                  -- Pseudo-transparency for floating windows
vim.opt.fillchars      = { eob = " " }       -- Hide ~ at the end of buffer

-- ── Netrw (Built-in File Explorer) ──────────────────────────────────────────
vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3
vim.g.netrw_browse_split = 4
vim.g.netrw_altv = 1
vim.g.netrw_winsize = 25

-- ── leader key ───────────────────────────────────────────────────────────────
vim.g.mapleader      = " "
vim.g.maplocalleader = " "

-- ── keymaps ──────────────────────────────────────────────────────────────────
local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

-- File Explorer Toggle (built-in netrw)
map("n", "<leader>e", ":Lexplore<CR>", "Toggle File Explorer")

-- windows
map("n", "<C-h>", "<C-w>h",          "Move to left window")
map("n", "<C-l>", "<C-w>l",          "Move to right window")
map("n", "<C-j>", "<C-w>j",          "Move to lower window")
map("n", "<C-k>", "<C-w>k",          "Move to upper window")

-- buffers
map("n", "<S-l>", ":bnext<CR>",      "Next buffer")
map("n", "<S-h>", ":bprev<CR>",      "Prev buffer")

-- keep visual selection when indenting
map("v", "<",    "<gv",              "Indent left")
map("v", ">",    ">gv",              "Indent right")

-- move selected lines
map("v", "J",    ":m '>+1<CR>gv=gv", "Move selection down")
map("v", "K",    ":m '<-2<CR>gv=gv", "Move selection up")

-- center cursor after jumps
map("n", "<C-d>", "<C-d>zz",         "Scroll down, centered")
map("n", "<C-u>", "<C-u>zz",         "Scroll up, centered")
map("n", "n",     "nzzzv",           "Next search result, centered")
map("n", "N",     "Nzzzv",           "Prev search result, centered")

-- paste without losing register
map("x", "<leader>p", '"_dP',        "Paste without clobbering register")

-- clear search highlight
map("n", "<Esc>", ":noh<CR>",        "Clear search highlight")

-- ── Built-in Minimal Statusline ──────────────────────────────────────────────
local modes = {
  ["n"]  = "NORMAL",  ["no"] = "N-OPERATOR", ["v"]  = "VISUAL",  ["V"]  = "V-LINE",
  ["\22"] = "V-BLOCK", ["s"]  = "SELECT",    ["S"]  = "S-LINE",  ["\19"] = "S-BLOCK",
  ["i"]  = "INSERT",  ["ic"] = "INSERT",    ["R"]  = "REPLACE", ["Rv"] = "V-REPLACE",
  ["c"]  = "COMMAND", ["cv"] = "VIM EX",    ["ce"] = "EX",      ["r"]  = "PROMPT",
  ["rm"] = "MORE",    ["r?"] = "CONFIRM",   ["!"]  = "SHELL",   ["t"]  = "TERMINAL",
}

function _G.statusline()
  local m = modes[vim.api.nvim_get_mode().mode] or "UNKNOWN"
  local filepath = " %f %m%r"
  local align = "%="
  local linecol = " %l:%c %p%% "
  return string.format("  %%#StatusLineMode# %s %%* %s %s %s", m, filepath, align, linecol)
end

vim.opt.statusline = "%!v:lua.statusline()"

-- ── Filetype tweaks & Markdown Enhancements ──────────────────────────────────
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap          = true
    vim.opt_local.spell         = true
    vim.opt_local.spelllang     = "en_us"

    -- Markdown visual enhancements (built-in conceallevel)
    if vim.bo.filetype == "markdown" then
      vim.opt_local.conceallevel = 2
      vim.opt_local.concealcursor = "nc"
    end
  end,
})

-- restore last cursor position on file open
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- strip trailing whitespace on save (skip filetypes where trailing space is meaningful)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    local ft = vim.bo.filetype
    if ft == "markdown" or ft == "text" then return end
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})

-- highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank({ timeout = 200 }) end,
})
