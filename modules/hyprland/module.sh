# Hyprland features: each one is a file in ~/.config/hypr/dotfiles/, turned
# on or off in ~/.config/hypr/dotfiles.lua, which hyprland.lua requires.

# item|feature file|comment in dotfiles.lua
HYPR_FEATURES=(
  "workspace-keys|workspace_keys|SUPER + CTRL + LEFT/RIGHT: previous/next workspace"
  "macos-keys|macos_keys|ALT as Cmd: Alt+C/V/X, Alt+A/Z/S/F/T/W/L/R, Alt+1..9, SUPER + Q, CTRL + ALT + SPACE emojis"
  "clipboard|clipboard_keys|ALT + SHIFT + V: clipboard history with pins"
  "gestures|gestures|3-finger swipe left/right: switch workspace"
  "natural-scroll|natural_scroll|Touchpad: natural (macOS) scrolling, slower"
  "touchscreen-off|touchscreen_off|Touchscreen turned off"
  "caps-lock|caps_lock|Real Caps Lock, Compose on Right Ctrl"
  "zoom|zoom|3-finger click, then swipe up/down: zoom like macOS"
  "workspace-animation|workspace_animation|Slide between workspaces"
  "no-middle-paste|no_middle_paste|Middle click (3-finger tap) doesn't paste"
  "whichport|whichport_window|whichport opens as a floating window"
)

detect_touchscreen() {
  if is_live && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl devices -j | jq -r '.touch[0].name // empty'
  elif [[ -f $HOME/.config/hypr/dotfiles.lua ]]; then
    sed -n 's/^ *touchscreen = "\(.*\)",.*/\1/p' "$HOME/.config/hypr/dotfiles.lua"
  fi
}

detect_touchpad() {
  if is_live && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl devices -j | jq -r '[.mice[].name | select(test("touchpad"; "i"))][0] // empty'
  elif [[ -f $HOME/.config/hypr/dotfiles.lua ]]; then
    sed -n 's/^ *touchpad = "\(.*\)",.*/\1/p' "$HOME/.config/hypr/dotfiles.lua"
  fi
}

module_hyprland() {
  local dir="$DOTFILES_DIR/modules/hyprland"
  local hypr="$HOME/.config/hypr"
  info "Hyprland"

  local file
  for file in "$dir"/features/*.lua; do
    install_file "$file" "$hypr/dotfiles/$(basename "$file")"
  done

  local touchpad
  touchpad=$(detect_touchpad)
  if selected zoom && [[ -z $touchpad ]]; then
    warn "aucun pavé tactile trouvé : le zoom reste inactif (réglage touchpad dans $(pretty "$hypr/dotfiles.lua"))"
  fi

  local touchscreen
  touchscreen=$(detect_touchscreen)

  local entry item feature comment lines=""
  for entry in "${HYPR_FEATURES[@]}"; do
    IFS='|' read -r item feature comment <<<"$entry"
    local state=false
    selected "$item" && state=true
    lines+=$(printf '  { %-24s %-6s -- %s' "\"$feature\"," "$state }," "$comment")$'\n'
  done

  write_file "$hypr/dotfiles.lua" <<EOF
-- Hyprland features from the dotfiles repo, one file each in hypr/dotfiles/.
-- Set one to false and run \`hyprctl reload\` to turn it off. ./install.sh
-- rewrites this file from its saved choices, so to keep a change, use
-- ./install.sh --disable <item> (or ./install.sh <item> to turn one on).
local features = {
${lines}}

local settings = {
  touchpad = "${touchpad}", -- for zoom, from \`hyprctl devices\`
  touchscreen = "${touchscreen}", -- for touchscreen_off, from \`hyprctl devices\`
}

for _, feature in ipairs(features) do
  local module = "hypr.dotfiles." .. feature[1]
  if feature[2] and package.searchpath(module, package.path) then
    require(module)(settings)
  end
end
EOF

  local main="$hypr/hyprland.lua"
  if [[ -f $main ]] && ! grep -q '^require("hypr.dotfiles")' "$main"; then
    backup "$main"
    if grep -q '^require("hypr.autostart")' "$main"; then
      sed -i 's/^require("hypr.autostart")$/&\nrequire("hypr.dotfiles")/' "$main"
    else
      printf '\n-- Features from the dotfiles repo (see hypr/dotfiles.lua)\nrequire("hypr.dotfiles")\n' >>"$main"
    fi
    ok "$(pretty "$main") charge maintenant hypr/dotfiles.lua"
  fi

  # The same customizations written straight into Omarchy's files would run twice
  local found
  found=$(grep -lE '\(macOS style\)|require\("hypr\.zoom"\)|middle_click_paste|org\.omarchy\.whichport|leaf = "workspaces", enabled = true|"SUPER \+ CTRL \+ LEFT", "Previous workspace"|natural_scroll = true|touchscreen_enabled|compose:rctrl|"CTRL \+ ALT \+ SPACE"' \
    "$hypr"/{bindings,input,looknfeel,hyprland}.lua 2>/dev/null || true)
  if [[ -n $found ]]; then
    warn "ces fichiers contiennent déjà certains de ces réglages, en double avec hypr/dotfiles/ :"
    printf '      %s\n' $found | sed "s|$HOME|~|" >&2
    todo "Retire ces réglages en double de ~/.config/hypr (README, « Migrer une machine déjà configurée »)."
  fi
}
