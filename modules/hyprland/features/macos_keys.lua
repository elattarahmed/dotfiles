-- macOS-style shortcuts on ALT (Alt sits where Cmd is on a Mac keyboard).
--
-- Clipboard follows Omarchy's SUPER + C/V/X in default/hypr/bindings/clipboard.lua:
-- terminals get keys they understand, so Ctrl+C still interrupts there.
-- Everything else behaves like Cmd + key outside terminals; in terminals the
-- original ALT chord is passed through untouched (Ctrl+Z/S would
-- suspend/freeze, and zsh has its own ALT bindings in ~/.zshrc).
--
-- Terminals in a browser tab (Proxmox's xterm.js console) work like Ghostty:
-- Alt+C copies the mouse selection to this PC (Ctrl+Insert: xterm.js leaves it
-- to the browser, which copies), Alt+V pastes this PC's clipboard
-- (Shift+Insert), and every other ALT chord reaches the remote shell as is.
-- Ctrl+Insert/Shift+Insert also copy/paste in the web UI's own text fields.
--
-- Remote screens (noVNC, VM viewers, remote desktops) get the original ALT
-- chord: they forward keys to another machine, where Alt+C turned into Ctrl+C
-- would kill the running command.
--
-- Add a window to the lists below (Lua patterns, matched case-insensitively
-- against the title or the class; `hyprctl clients` shows both).

local WEB_TERMINAL_TITLES = {
  "proxmox",            -- Proxmox VE web UI and its xterm.js console
  "xterm",
}
local REMOTE_TITLES = {
  "novnc",
  "guacamole",
  "idrac", "ilo %d", "ipmi", "kvm console",
}
local REMOTE_CLASSES = {
  "virt%-viewer", "remote%-viewer", "virt%-manager", "spicy",
  "virtualbox", "vmware", "qemu",
  "remmina", "xfreerdp", "wlfreerdp", "sdl%-freerdp", "rustdesk", "anydesk",
  "org%.gnome%.connections", "krdc",
}

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

local function matches_any(text, patterns)
  text = (text or ""):lower()
  for _, pattern in ipairs(patterns) do
    if text:find(pattern) then return true end
  end
  return false
end

local function active_window_is_remote()
  local window = hl.get_active_window()
  if not window then return false end
  return matches_any(window.title, REMOTE_TITLES)
    or matches_any(window.class, REMOTE_CLASSES)
    or matches_any(window.initial_class, REMOTE_CLASSES)
end

local function active_window_is_web_terminal()
  local window = hl.get_active_window()
  return window ~= nil and matches_any(window.title, WEB_TERMINAL_TITLES)
end

-- Alt+C/V/X in a browser terminal: copy / paste through the browser, cut is
-- the remote shell's own (Alt+X, as in Ghostty)
local WEB_TERMINAL_CLIPBOARD = {
  C = { "CTRL", "Insert" },
  V = { "SHIFT", "Insert" },
  X = { "ALT", "X" },
}

local function clipboard_shortcut(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    if active_window_is_web_terminal() then
      local keys = WEB_TERMINAL_CLIPBOARD[default_key]
      send_shortcut_once(keys[1], keys[2])()
    elseif active_window_is_remote() then
      send_shortcut_once("ALT", default_key)()
    elseif active_window_is_terminal() then
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

-- web_chords: what a browser terminal gets instead of the ALT chord. Its
-- remote shell is usually bash, which reads Alt+arrows as word moves; Home,
-- End, Ctrl+U and Ctrl+K mean the same thing in every shell.
local function mac_bind(mods, key, description, chords, send_key, web_chords)
  local combo = mods == "" and ("ALT + " .. key) or ("ALT + " .. mods .. " + " .. key)
  local passthrough = send_shortcut_once(mods == "" and "ALT" or ("ALT " .. mods), send_key or key)
  local action = send_sequence(chords)
  local web_action = web_chords and send_sequence(web_chords) or passthrough
  o.bind(combo, description .. " (macOS style)", function()
    if active_window_is_web_terminal() then
      web_action()
    elseif active_window_is_terminal() or active_window_is_remote() then
      passthrough()
    else
      action()
    end
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
  -- (last argument: what a browser terminal such as Proxmox's xterm.js gets)
  local home, finish = { { "", "Home" } }, { { "", "End" } }
  mac_bind("", "LEFT", "Line start", { { "", "Home" } }, nil, home)
  mac_bind("", "RIGHT", "Line end", { { "", "End" } }, nil, finish)
  mac_bind("", "UP", "Document start", { { "CTRL", "Home" } }, nil, home)
  mac_bind("", "DOWN", "Document end", { { "CTRL", "End" } }, nil, finish)
  mac_bind("SHIFT", "LEFT",  "Select to line start",     { { "SHIFT", "Home" } }, nil, home)
  mac_bind("SHIFT", "RIGHT", "Select to line end",       { { "SHIFT", "End" } }, nil, finish)
  mac_bind("SHIFT", "UP",    "Select to document start", { { "CTRL SHIFT", "Home" } }, nil, home)
  mac_bind("SHIFT", "DOWN",  "Select to document end",   { { "CTRL SHIFT", "End" } }, nil, finish)
  mac_bind("", "BACKSPACE", "Delete to line start", { { "SHIFT", "Home" }, { "", "BackSpace" } }, nil, { { "CTRL", "U" } })
  mac_bind("", "DELETE", "Delete to line end", { { "SHIFT", "End" }, { "", "Delete" } }, nil, { { "CTRL", "K" } })

  -- Shift + arrows in a browser terminal: bash can't select from the keyboard
  -- and prints the escape code (";2D") instead, so they just move. Bound only
  -- while such a window is focused: everywhere else Shift + arrows still select.
  local web_keys = {
    { "SHIFT + LEFT", "", "Left" }, { "SHIFT + RIGHT", "", "Right" },
    { "SHIFT + UP", "", "Up" }, { "SHIFT + DOWN", "", "Down" },
    { "SHIFT + HOME", "", "Home" }, { "SHIFT + END", "", "End" },
    { "CTRL + SHIFT + LEFT", "CTRL", "Left" }, { "CTRL + SHIFT + RIGHT", "CTRL", "Right" },
  }
  local web_binds = nil
  local function update_web_keys()
    local wanted = active_window_is_web_terminal()
    if wanted and not web_binds then
      web_binds = {}
      for _, k in ipairs(web_keys) do
        table.insert(web_binds, hl.bind(k[1], send_shortcut_once(k[2], k[3]), { repeating = true }))
      end
    elseif not wanted and web_binds then
      for _, bind in ipairs(web_binds) do pcall(function() bind:unbind() end) end
      web_binds = nil
    end
  end
  -- Deferred a tick, so the active window is already the new one
  local function later() hl.timer(update_web_keys, { timeout = 1, type = "oneshot" }) end
  hl.on("window.active", later)
  hl.on("window.title", later)  -- switching browser tabs only changes the title
  update_web_keys()

  -- Close window with SUPER + Q too (SUPER + W still works)
  o.bind("SUPER + Q", "Close window", hl.dsp.window.close())

  -- Emoji picker, like Ctrl+Cmd+Space on macOS (laptop Fn keys are usually
  -- invisible to the system). SUPER + CTRL + E still works.
  o.bind("CTRL + ALT + SPACE", "Emojis", "omarchy-shell shell toggle omarchy.emojis")
end
