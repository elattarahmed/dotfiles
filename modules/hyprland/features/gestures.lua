-- Three-finger swipe left/right switches workspace. Up/down zooms, but only
-- after a 3-finger click: see zoom.lua.
return function()
  hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
end
