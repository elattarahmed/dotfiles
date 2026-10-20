-- Caps Lock is a real Caps Lock (é è ç à ù -> É È Ç À Ù). Omarchy's default
-- puts Compose on Caps Lock; it moves to Right Ctrl here.
return function()
  hl.config({ input = { kb_options = "compose:rctrl,shift:both_capslock_cancel" } })
end
