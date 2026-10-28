-- Screenshot on SUPER + SHIFT + S too (PRINT still works), like Windows.
-- Omarchy puts Google Maps there: dropped.
return function()
  hl.unbind("SUPER + SHIFT + S")
  o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")
end
