-- Slightly rounded corners instead of Omarchy's square ones. The Omarchy
-- shell mirrors Hyprland's decoration:rounding (Style.cornerRadius), so this
-- one value also rounds the bar's panels, menus, the polkit and sudo windows
-- and the lock screen's field.
local ROUNDING = 8 -- pixels; 0 = square, as Omarchy ships

return function()
  hl.config({
    decoration = { rounding = ROUNDING },
    -- Tabs of grouped windows, to match
    group = { groupbar = { gradient_rounding = math.max(0, ROUNDING - 2) } },
  })
end
