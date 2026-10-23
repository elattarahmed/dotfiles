-- macOS-style screen zoom driven by the touchpad.
--
--   3-finger click          enter "zoom adjust" mode
--     ...then 3-finger swipe up/down     zoom in/out, lifting the fingers leaves the mode
--     ...or keep the click held and drag up/down, releasing leaves the mode
--   3-finger double click   zoomed: back to normal view / normal: back to the previous zoom
--
-- The cursor stays centered while zoomed; near a screen edge the view stops at
-- the edge instead of going past it (cursor.zoom_rigid).
-- SUPER + CTRL + Z / SUPER + CTRL + ALT + Z (Omarchy defaults) still work.
--
-- The touchpad comes from settings.touchpad in ~/.config/hypr/dotfiles.lua
-- (install.sh fills it from `hyprctl devices`); without one only the keyboard
-- zoom out is set up, so middle clicks from a mouse are never taken over.

local MIN_ZOOM, MAX_ZOOM = 1, 10
local SWIPE_SPEED = 0.006   -- zoom change per unit of 3-finger swipe
local DRAG_SPEED = 0.008    -- zoom change per pixel of held-click drag
local DRAG_DEADZONE = 8     -- pixels of movement before a held click starts zooming
local DOUBLE_CLICK_MS = 350
local MODE_TIMEOUT_MS = 3000 -- leave the mode if nothing happens after the click

return function(settings)
  -- Keep the cursor centered while zoomed (the view still stops at screen edges)
  hl.config({ cursor = { zoom_detached_camera = false, zoom_rigid = true } })

  -- Zoom changes inherit the 1s global animation by default; speed is in
  -- tenths of a second, so 1.5 = 150ms.
  hl.animation({ leaf = "zoomFactor", enabled = true, speed = 1.5, bezier = "easeOutQuint" })

  local state = {
    active = false,     -- "zoom adjust" mode
    held = false,       -- 3-finger click still pressed
    adjusted = false,   -- zoom changed since entering the mode
    swiping = false,
    click_pending = false,
    previous = 2,       -- zoom restored by a double click from the normal view
    anchor = nil,       -- cursor position while dragging with the click held
    dragging = false,   -- held-click drag went past the dead zone
    generation = 0,     -- invalidates stale timeouts
  }

  local function get_zoom()
    return tonumber(hl.get_config("cursor.zoom_factor")) or 1
  end

  local function set_zoom(zoom)
    zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, zoom))
    if zoom < 1.02 then zoom = 1 end
    hl.config({ cursor = { zoom_factor = zoom } })
  end

  local function scale_zoom(delta, speed)
    -- Up (negative delta) zooms in; exponential so it feels the same at any level
    set_zoom(get_zoom() * math.exp(-delta * speed))
    state.adjusted = true
  end

  -- Held-click drag: read how far the cursor moved, zoom by that, then put the
  -- cursor back so the zoomed spot stays put.
  local drag_timer = hl.timer(function()
    if not (state.active and state.held and state.anchor) then return end
    local pos = hl.get_cursor_pos()
    local dy = pos.y - state.anchor.y
    -- Ignore the small jitter of pressing the touchpad down
    if not state.dragging then
      if math.abs(dy) < DRAG_DEADZONE then return end
      state.dragging = true
    end
    if math.abs(dy) < 1 then return end
    scale_zoom(dy, DRAG_SPEED)
    hl.dispatch(hl.dsp.cursor.move({ x = state.anchor.x, y = state.anchor.y }))
  end, { timeout = 16, type = "repeat" })
  drag_timer:set_enabled(false)

  local function leave_mode()
    state.active = false
    state.held = false
    state.swiping = false
    state.anchor = nil
    state.generation = state.generation + 1
    drag_timer:set_enabled(false)
  end

  local function enter_mode()
    state.active = true
    state.adjusted = false
    state.generation = state.generation + 1
    local generation = state.generation
    hl.timer(function()
      if state.generation == generation and state.active and not state.held and not state.swiping then
        leave_mode()
      end
    end, { timeout = MODE_TIMEOUT_MS, type = "oneshot" })
  end

  local function toggle_normal_view()
    local zoom = get_zoom()
    if zoom > 1 then
      state.previous = zoom
      set_zoom(1)
    else
      set_zoom(state.previous)
    end
  end

  -- Keyboard zoom out: the opposite of Omarchy's SUPER + CTRL + Z (one step per press).
  o.bind("SUPER + CTRL + SHIFT + Z", "Zoom out", function()
    set_zoom(get_zoom() - 1)
  end)

  -- Everything below needs the touchpad
  local TOUCHPAD = settings.touchpad
  if not TOUCHPAD or TOUCHPAD == "" then return end

  local touchpad_only = { device = { inclusive = true, list = { TOUCHPAD } } }

  o.bind("mouse:274", "Zoom: adjust mode (3-finger click)", function()
    if state.click_pending then
      -- Second click in a row: double click
      state.click_pending = false
      leave_mode()
      toggle_normal_view()
      return
    end

    state.click_pending = true
    hl.timer(function() state.click_pending = false end, { timeout = DOUBLE_CLICK_MS, type = "oneshot" })

    enter_mode()
    state.held = true
    state.dragging = false
    local pos = hl.get_cursor_pos()
    state.anchor = { x = pos.x, y = pos.y }
    drag_timer:set_enabled(true)
  end, touchpad_only)

  o.bind("mouse:274", "Zoom: release 3-finger click", function()
    if not state.held then return end
    state.held = false
    state.anchor = nil
    drag_timer:set_enabled(false)
    -- Releasing after a drag ends the adjustment; a plain click keeps the mode
    -- open for a 3-finger swipe.
    if state.adjusted then leave_mode() end
  end, { release = true, device = touchpad_only.device })

  hl.gesture({
    fingers = 3,
    direction = "vertical",
    action = {
      start = function(e)
        if not state.active then return end
        state.swiping = true
        scale_zoom(e.delta.y, SWIPE_SPEED)
      end,
      update = function(e)
        if not (state.active and state.swiping) then return end
        scale_zoom(e.delta.y, SWIPE_SPEED)
      end,
      finish = function()
        if state.swiping then leave_mode() end
      end,
    },
  })

  -- Alt + 3-finger click: swallow it, otherwise it reaches Ghostty as a middle
  -- click and pastes (Ghostty's middle-click paste can't be turned off).
  o.bind("ALT + mouse:274", "Ignore Alt + 3-finger click (no paste)", function() end, touchpad_only)
end
