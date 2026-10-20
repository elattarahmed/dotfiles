-- Slide between workspaces (Omarchy turns this animation off by default).
return function()
  hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "easeOutQuint", style = "slide" })
end
