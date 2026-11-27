# Connection and display widgets in the tray's drawer instead of the bar:
# Wi-Fi, Bluetooth, AirPods, VPN, local and public IP, screen scale and
# brightness hide behind the tray's arrow and slide out when it is hovered
# (Omarchy draws the bar's "tray" section in that drawer). Runs after the
# modules that add those widgets (AirPods, interstellar-bar), so a new
# machine gets them in the drawer too.
# Item: bar-drawer

BAR_DRAWER_IDS=(omarchy.network omarchy.bluetooth io.github.sotoaugusto.airpods
  interstellar-vpn interstellar-local-ip interstellar-public-ip
  dotfiles.display-scale omarchy.monitor)

# bar_section ID: the bar section the widget is in (empty if not in the bar)
bar_section() {
  jq -r --arg id "$1" '(.bar.layout // {}) | to_entries[] | select(any(.value[]?; .id == $id)) | .key' \
    "$HOME/.config/omarchy/shell.json" 2>/dev/null | head -n 1
}

module_bar_drawer() {
  is_live || return 0
  [[ -f $HOME/.config/omarchy/shell.json ]] && command -v omarchy >/dev/null || return 0
  local id section moved=0
  if selected bar-drawer; then
    for id in "${BAR_DRAWER_IDS[@]}"; do
      section=$(bar_section "$id")
      [[ -n $section && $section != tray ]] || continue
      omarchy bar move "$id" --section tray >/dev/null 2>&1 && moved=$((moved + 1))
    done
    ((moved)) && { info "Barre : tiroir des connexions"; ok "$moved élément(s) rangé(s) dans le tiroir (survol de la flèche de la zone de notification)"; }
  else
    # Back in the bar, just before the tray, in the list's order
    for id in "${BAR_DRAWER_IDS[@]}"; do
      [[ $(bar_section "$id") == tray ]] || continue
      omarchy bar move "$id" --before omarchy.tray >/dev/null 2>&1 && moved=$((moved + 1))
    done
    ((moved)) && { info "Barre : tiroir des connexions"; ok "$moved élément(s) remis dans la barre"; }
  fi
  return 0
}
