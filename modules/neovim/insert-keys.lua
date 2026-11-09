-- Insert mode moves and deletes like in a browser or a text editor, with the
-- same keys as zsh (macos-keys: Alt plays Cmd on a Mac):
--
--   Ctrl+← / →             start / end of the word
--   Ctrl+↑ / ↓             previous / next paragraph (blank line)
--   Alt+← / →              start of the line (indent first, then column 0) / end of the line
--   Alt+↑ / ↓              start / end of the file
--   Ctrl+Backspace / Del   delete the word before / after
--   Alt+Backspace / Del    delete to the start of the line (indent first) / to the end
--
-- A word is Vim's: a run of letters and digits (accents included) or a run of
-- punctuation. Moves skip the spaces and line breaks in between. Deletion stays
-- on the line: at its start (or end) it only joins it with the previous (or
-- next) one, like Backspace (or Delete).

local word = [[\%(\k\+\|\%(\k\@!\S\)\+\)]]
local word_from = [[\%(\k\@<!\k\+\|\%(\k\@!\S\)\@<!\%(\k\@!\S\)\+\)]]
local word_end = [[\%#\_s*]] .. word .. [[\zs]]
local word_start = word_from .. [[\_s*\%#]]

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

-- Deletes between the cursor and col on the current line, or sends key (<BS> or
-- <Del>) when the cursor is already at that end of the line.
local function delete_to(target, key)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local len = #vim.api.nvim_get_current_line()
  if (key == "<BS>" and col == 0) or (key == "<Del>" and col >= len) then
    vim.api.nvim_feedkeys(vim.keycode(key), "ni", false)
    return
  end
  local to = target(row, col, len)
  local from, upto = math.min(col, to), math.max(col, to)
  vim.api.nvim_buf_set_text(0, row - 1, from, row - 1, upto, {})
  jump(row, from)
end

local function before_word(row)
  local pos = vim.fn.searchpos(word_from .. [[\s*\%#]], "bnW", row)
  return pos[1] == row and pos[2] - 1 or 0
end

local function after_word(row, _, len)
  local pos = vim.fn.searchpos([[\%#\s*]] .. word .. [[\zs]], "cnW", row)
  return pos[1] == row and pos[2] - 1 or len
end

local function before_line(_, col)
  local indent = #vim.api.nvim_get_current_line():match("^%s*")
  return col > indent and indent or 0
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
  { "<C-BS>", function() delete_to(before_word, "<BS>") end, "Effacer le mot avant" },
  -- What Ctrl+Backspace sends when the terminal doesn't tell it apart
  { "<C-h>", function() delete_to(before_word, "<BS>") end, "Effacer le mot avant" },
  { "<C-Del>", function() delete_to(after_word, "<Del>") end, "Effacer le mot après" },
  { "<A-BS>", function() delete_to(before_line, "<BS>") end, "Effacer jusqu'au début de la ligne" },
  { "<A-Del>", function() delete_to(function(_, _, len) return len end, "<Del>") end, "Effacer jusqu'à la fin de la ligne" },
}

for _, key in ipairs(keys) do
  vim.keymap.set("i", key[1], key[2], { desc = key[3] })
end
