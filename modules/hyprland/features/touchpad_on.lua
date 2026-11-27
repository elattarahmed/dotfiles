-- SUPER + CTRL + ALT + I: turn the touchpad back on, for when it was turned
-- off (the dashboard's shortcut, Omarchy's touchpad key, which the Framework's
-- keyboard doesn't have). From the touchpad itself there is no way back.
return function()
  o.bind("SUPER + CTRL + ALT + I", "Turn touchpad on", "omarchy-toggle-touchpad on")
end
