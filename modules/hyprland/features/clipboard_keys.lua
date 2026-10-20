-- Clipboard history, Maccy-style: ALT + SHIFT + V (SUPER + CTRL + V still
-- works). Opens the verybad.clipboard plugin, Omarchy's picker with pins.
return function()
  hl.unbind("SUPER + CTRL + V")
  o.bind("SUPER + CTRL + V", "Clipboard history", "omarchy-shell shell toggle verybad.clipboard")
  o.bind("ALT + SHIFT + V", "Clipboard history", "omarchy-shell shell toggle verybad.clipboard")
end
