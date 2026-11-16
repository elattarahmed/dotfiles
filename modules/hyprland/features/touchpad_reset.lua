-- SUPER + CTRL + ALT + P: reset a touchpad that believes fingers are still
-- on it (moving scrolls, scrolling zooms). See touchpad-reset.
return function()
  o.bind("SUPER + CTRL + ALT + P", "Reset touchpad", "touchpad-reset")
end
