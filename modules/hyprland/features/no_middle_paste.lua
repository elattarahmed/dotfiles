-- A three-finger tap or click is a middle click: never let it paste.
--
-- middle_click_paste = false stops Hyprland's primary selection, but some apps
-- (Ghostty) paste on a middle click on their own. So the touchpad's middle
-- click doesn't reach apps at all, whatever keys are held: zoom.lua takes it
-- for the zoom when that feature is on, and this file swallows it otherwise.
-- A real mouse's middle button is left alone (it still opens links in new tabs).
return function(settings)
  hl.config({ misc = { middle_click_paste = false } })

  local touchpad = settings.touchpad
  if settings.touchpad_middle_taken or not touchpad or touchpad == "" then return end
  local touchpad_only = { device = { inclusive = true, list = { touchpad } }, ignore_mods = true }
  o.bind("mouse:274", "Ignore 3-finger click/tap (no paste)", function() end, touchpad_only)
  o.bind("mouse:274", nil, function() end, { release = true, ignore_mods = true, device = touchpad_only.device })
end
