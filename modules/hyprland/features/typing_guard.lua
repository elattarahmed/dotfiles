-- Typing guard: a longer "disable while typing" than libinput's.
--
-- libinput only ignores touches that start while typing, and only for 0.2 to
-- 0.5 s after the last key; this touchpad reports neither pressure nor
-- contact size, so a palm can't be recognized by its shape. Here every plain
-- key press stops the cursor from moving until GUARD_MS after the last one.
--
-- The touchpad is never turned off: its acceleration is set to zero while
-- typing (a custom profile whose speed is 0), then put back. Turning it off
-- closed the device, and a finger resting on it at that moment came back
-- untracked: clicks still worked but the cursor no longer moved, or the
-- touchpad stayed unusable until reset.
--
-- Taps are off too while typing: a palm brushing the touchpad was a tap, so a
-- click where the pointer sat, and Neovim (or any editor) moved the text
-- cursor there mid-sentence. A real click (pressing the touchpad down) still
-- goes through, and Ctrl/Shift + click works anyway: a modifier ends the guard.
--
-- Modifier keys never start the guard, nor do keys typed with a modifier held
-- (Ctrl+C...), and pressing a modifier ends it at once.
local GUARD_MS = 800 -- how long after the last key the cursor stays still
local FROZEN = "custom 1 0.0 0.0" -- zero speed whatever the finger does

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
  local frozen = false
  local generation = 0 -- invalidates stale timers

  -- The acceleration the touchpad has the rest of the time (the global
  -- input setting: nothing sets one for this device alone)
  local function normal_profile()
    local profile = hl.get_config("input.accel_profile")
    if type(profile) ~= "string" or profile == "[[EMPTY]]" then return "" end
    return profile
  end

  -- Whether taps click the rest of the time (the global touchpad setting)
  local function normal_tap()
    return hl.get_config("input.touchpad.tap_to_click") ~= false
  end

  local function thaw()
    if not frozen then return end
    frozen = false
    generation = generation + 1
    hl.device({ name = touchpad, accel_profile = normal_profile(), tap_to_click = normal_tap() })
  end

  hl.on("input.keyboard.key", function(code, _, pressed)
    if MODIFIERS[code] then
      held[code] = pressed == 1 or nil
      if pressed == 1 then thaw() end
      return
    end
    if pressed ~= 1 or next(held) then return end

    if not frozen then
      frozen = true
      hl.device({ name = touchpad, accel_profile = FROZEN, tap_to_click = false })
    end
    generation = generation + 1
    local mine = generation
    hl.timer(function()
      if mine == generation then thaw() end
    end, { timeout = GUARD_MS, type = "oneshot" })
  end)
end
