-- Discord's global shortcuts. On Wayland Discord registers them with the
-- desktop portal (GlobalShortcuts) and says "approve it in your system's
-- global shortcut settings": on Hyprland that approval is a bind to the
-- `global` dispatcher, here. Keys like Discord's macOS ones (Cmd+Shift+M/D),
-- on SUPER + ALT (SUPER + SHIFT + M/D are Omarchy's Music and Docker).
-- The ids are the ones `hyprctl globalshortcuts` lists while Discord runs.
return function()
  o.bind("SUPER + ALT + M", "Discord: mute / unmute the microphone", hl.dsp.global("discord:discord-toggle-mute"))
  o.bind("SUPER + ALT + D", "Discord: deafen / undeafen", hl.dsp.global("discord:discord-toggle-deafen"))
  o.bind("SUPER + ALT + X", "Discord: leave the voice channel", hl.dsp.global("discord:discord-disconnect-from-voice-channel"))
end
