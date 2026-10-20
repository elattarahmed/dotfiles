-- A three-finger tap is a middle click: don't let it paste the last selection.
return function()
  hl.config({ misc = { middle_click_paste = false } })
end
