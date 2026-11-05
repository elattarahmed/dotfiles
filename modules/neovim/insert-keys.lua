-- Insert mode moves like in a browser or a text editor, with the same keys as
-- zsh (macos-keys: Alt plays Cmd on a Mac):
--
--   Ctrl+← / →   start / end of the word
--   Ctrl+↑ / ↓   previous / next paragraph (blank line)
--   Alt+← / →    start of the line (indent first, then column 0) / end of the line
--   Alt+↑ / ↓    start / end of the file
--
-- A word is Vim's: a run of letters and digits (accents included) or a run of
-- punctuation. Spaces and line breaks in between are skipped.

local word_end = [[\%#\_s*\%(\k\+\|\%(\k\@!\S\)\+\)\zs]]
local word_start = [[\%(\k\@<!\k\+\|\%(\k\@!\S\)\@<!\%(\k\@!\S\)\+\)\_s*\%#]]

local function jump(row, col)
  vim.api.nvim_win_set_cursor(0, { row, col })
end

local function search(pattern, flags)
  local pos = vim.fn.searchpos(pattern, flags)
  if pos[1] > 0 then
    jump(pos[1], pos[2] - 1)
  end
end

local function line_start()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local indent = #vim.api.nvim_get_current_line():match("^%s*")
  jump(row, col == indent and 0 or indent)
end

local function file_end()
  local last = vim.api.nvim_buf_line_count(0)
  jump(last, #vim.fn.getline(last))
end

local keys = {
  { "<C-Left>", function() search(word_start, "bnW") end, "Début du mot" },
  { "<C-Right>", function() search(word_end, "cnW") end, "Fin du mot" },
  { "<C-Up>", "<Cmd>normal! {<CR>", "Paragraphe précédent" },
  { "<C-Down>", "<Cmd>normal! }<CR>", "Paragraphe suivant" },
  { "<A-Left>", line_start, "Début de la ligne" },
  { "<A-Right>", function() jump(vim.fn.line("."), #vim.api.nvim_get_current_line()) end, "Fin de la ligne" },
  { "<A-Up>", function() jump(1, 0) end, "Début du fichier" },
  { "<A-Down>", file_end, "Fin du fichier" },
}

for _, key in ipairs(keys) do
  vim.keymap.set("i", key[1], key[2], { desc = key[3] })
end
