-- Typing guard: a longer "disable while typing" than libinput's.
--
-- libinput only ignores touches that start while typing, and only for 0.2 to
-- 0.5 s after the last key; this touchpad reports neither pressure nor
-- contact size, so a palm can't be recognized by its shape. Here every plain
-- key press turns the touchpad off until GUARD_MS after the last one.
--
-- Shortcuts keep working with the touchpad: modifier keys never turn it off,
-- nor do keys typed with a modifier held (Ctrl+C...), and pressing a modifier
-- turns it back on at once, so Ctrl/Shift + click works right after typing.
local GUARD_MS = 800 -- how long after the last key the touchpad stays off

-- xkb keycodes (evdev + 8), the same whatever the layout
local MODIFIERS = {
  [37] = true, [105] = true, -- Ctrl left/right
  [50] = true, [62] = true, -- Shift left/right
  [64] = true, [108] = true, -- Alt / AltGr
  [133] = true, [134] = true, -- Super left/right
  [66] = true, -- Caps Lock
}

return function(settings)
  local touchpad = settings.touchpad
  if not touchpad or touchpad == "" then return end

  local held = {} -- modifiers currently down
  local blocked = false
  local generation = 0 -- invalidates stale timers

  -- A touchpad turned off on purpose (omarchy toggle touchpad) stays off
  local function turned_off_on_purpose()
    local f = io.open((os.getenv("HOME") or "") .. "/.local/state/omarchy/toggles/hypr/touchpad-disabled-name", "r")
    if not f then return false end
    local name = f:read("*l")
    f:close()
    return name == touchpad
  end

  local function release()
    if not blocked then return end
    blocked = false
    generation = generation + 1
    if not turned_off_on_purpose() then
      hl.device({ name = touchpad, enabled = true })
    end
  end

  hl.on("input.keyboard.key", function(code, _, pressed)
    if MODIFIERS[code] then
      held[code] = pressed == 1 or nil
      if pressed == 1 then release() end
      return
    end
    if pressed ~= 1 or next(held) then return end

    if not blocked then
      if turned_off_on_purpose() then return end
      blocked = true
      hl.device({ name = touchpad, enabled = false })
    end
    generation = generation + 1
    local mine = generation
    hl.timer(function()
      if mine == generation then release() end
    end, { timeout = GUARD_MS, type = "oneshot" })
  end)
end
