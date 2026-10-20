# Display scale, through Omarchy's own command (it also sets GDK_SCALE and
# saves the value in ~/.config/hypr/monitors.lua). Depends on the screen, so
# it asks for the value and remembers it.
# Item: display-scale

module_display() {
  selected display-scale || return 0
  info "Échelle de l'écran"

  local saved="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/display-scale" scale=""
  [[ -f $saved ]] && scale=$(<"$saved")
  if [[ -z $scale ]] || explicit display-scale; then
    if ! interactive; then
      [[ -n $scale ]] || todo "Échelle de l'écran : lance ./install.sh display-scale dans un terminal pour choisir la valeur."
      [[ -n $scale ]] || return 0
    else
      scale=$(ask "Échelle (1 · 1.25 · 1.6 · 2 · auto) :" "${scale:-1.6}")
    fi
  fi
  [[ -n $scale ]] || return 0
  mkdir -p "$(dirname "$saved")"
  echo "$scale" >"$saved"

  is_live || return 0
  if [[ $scale == auto ]]; then
    backup "$HOME/.config/hypr/monitors.lua"
    sed -i 's/^local omarchy_monitor_scale = .*/local omarchy_monitor_scale = "auto"/' "$HOME/.config/hypr/monitors.lua"
    ok "échelle automatique"
  else
    omarchy hyprland monitor scaling "$scale" >/dev/null && ok "échelle $scale"
  fi
}
