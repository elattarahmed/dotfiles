# "Gestionnaire" and "Applications" in the bar, instead of Omarchy's
# connection icons and tray drawer:
#   - dotfiles.control-center: Wi-Fi, Bluetooth, AirPods, VPN, brightness,
#     scale and resize in one card, managed on its own (Quickshell's
#     Networking and Bluetooth, the AirPods plugin's state file and command)
#   - dotfiles.apps: the apps' tray icons, always shown, next to the agents
# The icons they replace leave the bar. The AirPods plugin stays enabled (the
# card reads its state), its icon in the bar's tray section, which nothing
# draws without Omarchy's tray. Runs after the modules that add those icons
# (AirPods, interstellar-bar), so a new machine ends up the same.
# Item: control-center

CC_REPLACED='["omarchy.network", "omarchy.bluetooth", "omarchy.monitor", "interstellar-vpn", "dotfiles.display-scale", "dotfiles.resize-mode", "omarchy.tray", "omarchy.audio"]'
CC_AIRPODS=io.github.sotoaugusto.airpods

cc_in_layout() {
  jq -e --arg id "$1" 'any(.bar.layout[]?[]?; .id == $id)' "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1
}
cc_section() {
  jq -r --arg id "$1" '(.bar.layout // {}) | to_entries[] | select(any(.value[]?; .id == $id)) | .key' \
    "$HOME/.config/omarchy/shell.json" 2>/dev/null | head -n 1
}

module_control_center() {
  local shell_json=$HOME/.config/omarchy/shell.json tmp id
  if selected control-center; then
    info "Gestionnaire et Applications"
    install_plugin dotfiles.control-center --before omarchy.power
    install_plugin dotfiles.apps --before omarchy.agents
    is_live && [[ -f $shell_json ]] || return 0
    # One write (each change of shell.json rebuilds the bar): the icons the
    # Gestionnaire replaces go, then the right side is ordered by role (bar-order.jq)
    tmp=$(mktemp)
    jq --argjson gone "$CC_REPLACED" '.bar.layout |= map_values(map(select(.id as $id | $gone | index($id) | not)))' "$shell_json" \
      | jq -f "$DOTFILES_DIR/modules/control-center/bar-order.jq" >"$tmp"
    if [[ -s $tmp ]] && ! cmp -s "$tmp" "$shell_json"; then
      backup "$shell_json"
      cat "$tmp" >"$shell_json"
      ok "barre rangée par groupes : applications · outils · musique · réseau · système et Gestionnaire · confidentialité (connexions, volume et tiroir dans le Gestionnaire)"
    fi
    rm -f "$tmp"
    # Keep the AirPods plugin (its state feeds the card), out of sight
    if cc_in_layout "$CC_AIRPODS" && [[ $(cc_section "$CC_AIRPODS") != tray ]]; then
      omarchy bar move "$CC_AIRPODS" --section tray >/dev/null 2>&1 && ok "icône AirPods masquée (le Gestionnaire l'affiche)"
    fi
  else
    is_live && omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "dotfiles.control-center" and .enabled)' >/dev/null || return 0
    info "Gestionnaire et Applications"
    disable_plugin dotfiles.control-center
    disable_plugin dotfiles.apps
    cc_in_layout omarchy.audio || omarchy bar put omarchy.audio --before omarchy.power >/dev/null 2>&1 || true
    for id in omarchy.tray omarchy.network omarchy.bluetooth omarchy.monitor; do
      cc_in_layout "$id" || omarchy bar put "$id" --before omarchy.audio >/dev/null 2>&1 || true
    done
    [[ $(cc_section "$CC_AIRPODS") == tray ]] && omarchy bar move "$CC_AIRPODS" --before omarchy.audio >/dev/null 2>&1
    ok "icônes d'Omarchy remises dans la barre"
  fi
  return 0
}
