-- Resize the active window from the keyboard: SUPER + R, then arrows, like
-- dragging its bottom-right corner (SHIFT for bigger steps). ESCAPE, RETURN or
-- SUPER + R again to leave.
return function()
  o.bind("SUPER + R", "Resize mode", function()
    hl.dispatch(hl.dsp.submap("resize"))
    hl.notification.create({ text = "Redimensionner : flèches (Maj = plus vite) · Échap pour finir", timeout = 2500, icon = "info" })
  end)

  hl.define_submap("resize", function()
    local function resize(x, y)
      return hl.dsp.window.resize({ x = x, y = y, relative = true })
    end
    local step, big = 40, 150
    hl.bind("RIGHT", resize(step, 0), { repeating = true })
    hl.bind("LEFT", resize(-step, 0), { repeating = true })
    hl.bind("DOWN", resize(0, step), { repeating = true })
    hl.bind("UP", resize(0, -step), { repeating = true })
    hl.bind("SHIFT + RIGHT", resize(big, 0), { repeating = true })
    hl.bind("SHIFT + LEFT", resize(-big, 0), { repeating = true })
    hl.bind("SHIFT + DOWN", resize(0, big), { repeating = true })
    hl.bind("SHIFT + UP", resize(0, -big), { repeating = true })
    hl.bind("ESCAPE", hl.dsp.submap("reset"))
    hl.bind("RETURN", hl.dsp.submap("reset"))
    hl.bind("SUPER + R", hl.dsp.submap("reset"))
  end)
end
