# AirPods in the bar (https://github.com/SotoAugusto/omarchy-airpods): battery,
# noise control and ear detection, through the airpods-tui daemon.
# Item: airpods

AIRPODS_PLUGIN_REPO=https://github.com/SotoAugusto/omarchy-airpods
AIRPODS_PLUGIN_ID=io.github.sotoaugusto.airpods
BLUETOOTH_CONF=/etc/bluetooth/main.conf
# BlueZ has to identify as Apple, or AirPods never open their control channel
APPLE_DEVICE_ID="DeviceID = bluetooth:004C:0000:0000"
APPLE_DEVICE_ID_RE='^[[:space:]]*DeviceID[[:space:]]*=[[:space:]]*bluetooth:004C:'

apple_device_ids() { grep -cE "$APPLE_DEVICE_ID_RE" "$BLUETOOTH_CONF" 2>/dev/null || true; }

module_airpods() {
  if ! selected airpods; then
    disable_plugin "$AIRPODS_PLUGIN_ID"
    return 0
  fi
  info "AirPods"
  is_live || return 0

  # Counted first: the airpods-tui package hook sets the DeviceID itself
  local ids_at_start
  ids_at_start=$(apple_device_ids)

  aur_add airpods-tui-bin
  command -v airpods-tui >/dev/null || return 0

  local ids
  ids=$(apple_device_ids)
  if ((ids != 1)) && ! can_sudo; then
    todo "AirPods : DeviceID Apple à régler dans $BLUETOOTH_CONF (relance ./install.sh dans un terminal)."
  elif ((ids == 0)); then
    if grep -q '^\[General\]' "$BLUETOOTH_CONF" 2>/dev/null; then
      sudo sed -i "/^\[General\]/a $APPLE_DEVICE_ID" "$BLUETOOTH_CONF"
    else
      printf '\n[General]\n%s\n' "$APPLE_DEVICE_ID" | sudo tee -a "$BLUETOOTH_CONF" >/dev/null
    fi
    ok "DeviceID Apple ajouté dans $BLUETOOTH_CONF"
  elif ((ids > 1)); then
    # Running the sed by hand more than once leaves duplicates: keep the first
    sudo sed -i "0,/$APPLE_DEVICE_ID_RE/b; /$APPLE_DEVICE_ID_RE/d" "$BLUETOOTH_CONF"
    ok "DeviceID Apple en double retiré de $BLUETOOTH_CONF"
  fi

  # New DeviceID (from us or the package hook): BlueZ only reads it on restart,
  # and only pairings made afterwards open the control channel
  if ((ids_at_start == 0)) && (($(apple_device_ids) > 0)) && can_sudo; then
    sudo systemctl restart bluetooth && ok "bluetooth redémarré"
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
    printf '{"waitingForFirstConnection":true}\n' >"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/airpods-onboarding.json"
    todo "AirPods : oublie-les dans les réglages Bluetooth puis appaire-les de nouveau (l'ancien appairage n'ouvre pas le canal de contrôle)."
  fi

  if systemctl --user is-enabled --quiet airpods-tui 2>/dev/null; then
    ok "airpods-tui déjà lancé à la connexion"
  elif systemctl --user enable --now airpods-tui >/dev/null 2>&1; then
    ok "airpods-tui lancé à la connexion"
  else
    warn "impossible d'activer airpods-tui (systemctl --user enable --now airpods-tui)"
  fi

  if ! omarchy plugin list --json 2>/dev/null | jq -e --arg id "$AIRPODS_PLUGIN_ID" 'any(.[]; .id == $id)' >/dev/null; then
    omarchy plugin add "$AIRPODS_PLUGIN_REPO" --yes >/dev/null || {
      warn "impossible d'installer le plugin AirPods (omarchy plugin add $AIRPODS_PLUGIN_REPO)"
      return 0
    }
    ok "plugin $AIRPODS_PLUGIN_ID installé"
  fi
  enable_plugin "$AIRPODS_PLUGIN_ID"
}
