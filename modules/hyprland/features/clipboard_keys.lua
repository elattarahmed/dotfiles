-- Clipboard history, Maccy-style: ALT + SHIFT + V (SUPER + CTRL + V still
-- works). Opens the dotfiles.clipboard plugin, Omarchy's picker with pins.
return function()
  hl.unbind("SUPER + CTRL + V")
  o.bind("SUPER + CTRL + V", "Clipboard history", "omarchy-shell shell toggle dotfiles.clipboard")
  o.bind("ALT + SHIFT + V", "Clipboard history", "omarchy-shell shell toggle dotfiles.clipboard")
end
