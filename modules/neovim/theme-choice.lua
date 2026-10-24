-- Neovim's colorscheme, picked on its own whatever the Omarchy theme.
--
--   <leader>uC or :Theme     picker with a live preview, Enter keeps the theme
--   :Theme <name>            keep that theme directly (Tab completes)
--   :Theme omarchy           follow the Omarchy theme again
--
-- The choice lives in ~/.local/state/nvim/theme-choice, so it survives restarts
-- and Omarchy theme changes (which otherwise reapply the Omarchy theme's own
-- colorscheme in plugins/theme.lua). This file sorts after theme.lua, so its
-- LazyVim opts win at startup.

local state = vim.fn.stdpath("state") .. "/theme-choice"
local transparency = vim.fn.stdpath("config") .. "/plugin/after/transparency.lua"

local function chosen()
  local ok, lines = pcall(vim.fn.readfile, state)
  local name = ok and lines[1] and vim.trim(lines[1]) or ""
  return name ~= "" and name or nil
end

local function remember(name)
  if name then
    vim.fn.writefile({ name }, state)
  else
    vim.fn.delete(state)
  end
end

local function apply(name)
  if not pcall(vim.cmd.colorscheme, name) then
    vim.notify("Thème introuvable : " .. name, vim.log.levels.WARN)
    return false
  end
  -- Omarchy keeps the terminal's background behind Neovim; redo it for this theme
  if vim.fn.filereadable(transparency) == 1 then
    vim.cmd.source(transparency)
  end
  return true
end

-- Installed colorschemes, loaded or not (what the picker lists), minus Vim's own
local function available()
  local rtp = vim.o.runtimepath
  if package.loaded.lazy then
    rtp = rtp .. "," .. table.concat(require("lazy.core.util").get_unloaded_rtp(""), ",")
  end
  local names = {}
  for _, file in ipairs(vim.fn.globpath(rtp, "colors/*", false, true)) do
    if not file:find(vim.env.VIMRUNTIME, 1, true) then
      names[vim.fn.fnamemodify(file, ":t:r")] = true
    end
  end
  local list = vim.tbl_keys(names)
  table.sort(list)
  return list
end

local function omarchy_colorscheme()
  package.loaded["plugins.theme"] = nil
  local ok, specs = pcall(require, "plugins.theme")
  if ok then
    for _, spec in ipairs(specs) do
      if spec[1] == "LazyVim/LazyVim" and spec.opts then
        return spec.opts.colorscheme
      end
    end
  end
end

local function pick()
  Snacks.picker.colorschemes({
    title = "Thème de Neovim · Entrée pour le garder",
    -- Vim's own old colorschemes (blue, desert…) only clutter the list
    transform = function(item)
      if item.file and item.file:find(vim.env.VIMRUNTIME, 1, true) then
        return false
      end
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      picker.preview.state.colorscheme = nil
      vim.schedule(function()
        if apply(item.text) then
          remember(item.text)
          vim.notify("Thème de Neovim : " .. item.text .. " (:Theme omarchy pour suivre Omarchy)")
        end
      end)
    end,
  })
end

local function theme_command(args)
  local name = vim.trim(args.args)
  if name == "" then
    pick()
  elseif name == "omarchy" then
    remember(nil)
    local scheme = omarchy_colorscheme()
    if scheme then
      apply(scheme)
    end
    vim.notify("Neovim suit de nouveau le thème Omarchy")
  elseif apply(name) then
    remember(name)
  end
end

return {
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      opts.colorscheme = chosen() or opts.colorscheme
    end,
  },
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>uC", pick, desc = "Thème de Neovim (gardé)" },
    },
  },
  -- VS Code's own colors, as one more choice
  { "Mofiqul/vscode.nvim", lazy = true, priority = 1000 },
  -- Only a config function: virtual, so lazy neither clones nor sources anything
  {
    name = "theme-choice",
    dir = vim.fn.stdpath("config"),
    virtual = true,
    lazy = false,
    config = function()
      vim.api.nvim_create_user_command("Theme", theme_command, {
        nargs = "?",
        desc = "Choisir le thème de Neovim",
        complete = function(lead)
          local names = vim.list_extend({ "omarchy" }, available())
          return vim.tbl_filter(function(n) return n:find(lead, 1, true) == 1 end, names)
        end,
      })
      -- An Omarchy theme change reapplies its colorscheme a few ms after
      -- LazyReload (plugins/omarchy-theme-hotreload.lua); put the kept one back
      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyReload",
        callback = function()
          local name = chosen()
          if name then
            vim.defer_fn(function() apply(name) end, 150)
          end
        end,
      })
    end,
  },
}
