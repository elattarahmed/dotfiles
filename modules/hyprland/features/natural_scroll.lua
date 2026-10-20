-- Touchpad scrolling like macOS: content follows the fingers, and slower than
-- Omarchy's 0.4.
return function()
  hl.config({ input = { touchpad = { natural_scroll = true, scroll_factor = 0.25 } } })
end
