-- Turns the touchscreen off. Its name comes from settings.touchscreen in
-- ~/.config/hypr/dotfiles.lua (install.sh fills it from `hyprctl devices`);
-- without one this does nothing.
return function(settings)
  local touchscreen = settings.touchscreen
  if not touchscreen or touchscreen == "" then return end
  hl.device({ name = touchscreen, enabled = false })
end
