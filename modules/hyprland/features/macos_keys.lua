-- macOS-style shortcuts on ALT (Alt sits where Cmd is on a Mac keyboard).
--
-- Clipboard follows Omarchy's SUPER + C/V/X in default/hypr/bindings/clipboard.lua:
-- terminals get keys they understand, so Ctrl+C still interrupts there.
-- Everything else behaves like Cmd + key outside terminals; in terminals the
-- original ALT chord is passed through untouched (Ctrl+Z/S would
-- suspend/freeze, and zsh has its own ALT bindings in ~/.zshrc).

local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

local function clipboard_shortcut(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    if active_window_is_terminal() then
      send_shortcut_once(terminal_mods, terminal_key)()
    else
      send_shortcut_once(default_mods, default_key)()
    end
  end
end

-- Send a sequence of chords, e.g. { { "SHIFT", "Home" }, { "", "BackSpace" } }
local function send_sequence(chords)
  return function()
    for i, chord in ipairs(chords) do
      hl.timer(send_shortcut_once(chord[1], chord[2]), { timeout = 1 + (i - 1) * 80, type = "oneshot" })
    end
  end
end

local function mac_bind(mods, key, description, chords, send_key)
  local combo = mods == "" and ("ALT + " .. key) or ("ALT + " .. mods .. " + " .. key)
  local passthrough = send_shortcut_once(mods == "" and "ALT" or ("ALT " .. mods), send_key or key)
  local action = send_sequence(chords)
  o.bind(combo, description .. " (macOS style)", function()
    if active_window_is_terminal() then passthrough() else action() end
  end)
end

return function()
  -- Clipboard. In terminals Alt+C/X reach Ghostty and zsh, which copy/cut
  -- their selection (see the ghostty and zsh-selection features).
  o.bind("ALT + C", "Copy (macOS style)", clipboard_shortcut("CTRL", "C", "ALT", "C"))
  o.bind("ALT + V", "Paste (macOS style)", clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"))
  o.bind("ALT + X", "Cut (macOS style)", clipboard_shortcut("CTRL", "X", "ALT", "X"))

  -- Editing
  mac_bind("", "A", "Select all", { { "CTRL", "A" } })
  mac_bind("", "Z", "Undo", { { "CTRL", "Z" } })
  mac_bind("SHIFT", "Z", "Redo", { { "CTRL SHIFT", "Z" } })
  mac_bind("", "S", "Save", { { "CTRL", "S" } })
  mac_bind("", "F", "Find", { { "CTRL", "F" } })

  -- Browser / tabs
  mac_bind("", "T", "New tab", { { "CTRL", "T" } })
  mac_bind("", "W", "Close tab", { { "CTRL", "W" } })
  mac_bind("SHIFT", "T", "Reopen closed tab", { { "CTRL SHIFT", "T" } })
  mac_bind("", "L", "Address bar", { { "CTRL", "L" } })
  mac_bind("", "R", "Reload", { { "CTRL", "R" } })
  for i = 1, 9 do
    -- code:10..18 = physical digit row, so it works on AZERTY too (like Omarchy workspaces)
    mac_bind("", "code:" .. (i + 9), "Tab " .. i, { { "CTRL", tostring(i) } }, tostring(i))
  end

  -- Text navigation (same as zsh: line start/end, document start/end, delete to line start/end)
  mac_bind("", "LEFT", "Line start", { { "", "Home" } })
  mac_bind("", "RIGHT", "Line end", { { "", "End" } })
  mac_bind("", "UP", "Document start", { { "CTRL", "Home" } })
  mac_bind("", "DOWN", "Document end", { { "CTRL", "End" } })
  mac_bind("", "BACKSPACE", "Delete to line start", { { "SHIFT", "Home" }, { "", "BackSpace" } })
  mac_bind("", "DELETE", "Delete to line end", { { "SHIFT", "End" }, { "", "Delete" } })

  -- Close window with SUPER + Q too (SUPER + W still works)
  o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

  -- Emoji picker, like Ctrl+Cmd+Space on macOS (laptop Fn keys are usually
  -- invisible to the system). SUPER + CTRL + E still works.
  o.bind("CTRL + ALT + SPACE", "Emojis", "omarchy-shell shell toggle omarchy.emojis")
end
