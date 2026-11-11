-- AltGr+O types œ (AltGr+Shift+O: Œ) instead of ø. The dotfiles:oe option is
-- defined in ~/.config/xkb (input-method module); xkbcommon ignores it when
-- that is missing. Added to the options already set (caps_lock runs first).
return function()
  local options = tostring(hl.get_config("input.kb_options") or "")
  if not options:find("dotfiles:oe", 1, true) then
    options = options == "" and "dotfiles:oe" or options .. ",dotfiles:oe"
  end
  hl.config({ input = { kb_options = options } })
end
