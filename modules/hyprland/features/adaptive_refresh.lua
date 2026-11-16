-- Adaptive refresh rate (VRR) on the built-in screen: it drops to ~34-48 Hz
-- when nothing moves (saves battery) and goes back to 120 Hz on motion.
-- Made for the Framework Laptop 13 AMD 2.8K panel; the adaptive-refresh
-- module also turns amdgpu's Panel Self Refresh / Panel Replay off at boot,
-- without which the screen stalls below 1 fps as soon as VRR is on.
return function()
  hl.config({
    misc = { vrr = 1 },
    -- With VRR, amdgpu drops hardware cursor updates while the panel runs
    -- slow, so the mouse would crawl: a software cursor makes every move a
    -- real frame and brings the panel back to 120 Hz.
    cursor = { no_hardware_cursors = 1 },
  })

  -- Live refresh rate, read from the kernel's vblank counter (hz draws
  -- nothing itself, so it doesn't push the panel up while measuring).
  o.bind("SUPER + CTRL + ALT + H", "Refresh rate monitor", "hz --toggle")
  o.window("org.omarchy.hz", { float = true, pin = true, size = { 560, 128 }, center = true })
end
