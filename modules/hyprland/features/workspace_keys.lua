-- Switch workspaces with SUPER + CTRL + arrows (was: grouped window focus;
-- SUPER + ALT + TAB still cycles a group).
return function()
  hl.unbind("SUPER + CTRL + LEFT")
  hl.unbind("SUPER + CTRL + RIGHT")
  o.bind("SUPER + CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
  o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))
end
