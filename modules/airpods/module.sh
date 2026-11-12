# AirPods in the bar: battery, noise control and ear detection, through the
# airpods-tui daemon (https://github.com/SotoAugusto/omarchy-airpods). The
# plugin stays a git clone, so `omarchy plugin update` keeps it current. This
# does what the plugin's own `setup` script does, without its questions.
# Item: airpods

AIRPODS_REPO=https://github.com/SotoAugusto/omarchy-airpods
AIRPODS_ID=io.github.sotoaugusto.airpods
BLUETOOTH_CONF=/etc/bluetooth/main.conf

airpods_device_id() { grep -qE '^[[:space:]]*DeviceID[[:space:]]*=[[:space:]]*bluetooth:004C:' "$BLUETOOTH_CONF" 2>/dev/null; }

module_airpods() {
  if ! selected airpods; then
    disable_plugin "$AIRPODS_ID"
    return 0
  fi
  info "AirPods"
  is_live || return 0

  # Sampled first: installing airpods-tui sets the DeviceID itself
  local had_device_id=0
  airpods_device_id && had_device_id=1

  aur_add airpods-tui-bin
  if ! command -v airpods-tui >/dev/null; then
    todo "AirPods : airpods-tui n'est pas installé, relance ./install.sh airpods dans un terminal."
    return 0
  fi

  local plugin="$HOME/.config/omarchy/plugins/$AIRPODS_ID"
  if [[ ! -d $plugin ]]; then
    if omarchy plugin add "$AIRPODS_REPO" --yes >/dev/null; then
      ok "plugin AirPods ajouté depuis $AIRPODS_REPO"
    else
      warn "impossible d'ajouter le plugin : omarchy plugin add $AIRPODS_REPO --enable"
      return 0
    fi
  fi
  # In the bar just before the volume, where it sits on the first machine
  enable_plugin "$AIRPODS_ID"
  omarchy bar move "$AIRPODS_ID" --before omarchy.audio >/dev/null 2>&1 || true

  # Without an Apple DeviceID the AirPods play audio but keep the control
  # channel (battery, noise modes) closed
  if ! airpods_device_id; then
    if ! can_sudo; then
      todo "AirPods : DeviceID Apple à mettre dans $BLUETOOTH_CONF, relance ./install.sh airpods dans un terminal."
      return 0
    fi
    backup "$BLUETOOTH_CONF"
    if grep -q '^\[General\]' "$BLUETOOTH_CONF" 2>/dev/null; then
      sudo sed -i '/^\[General\]/a DeviceID = bluetooth:004C:0000:0000' "$BLUETOOTH_CONF"
    else
      printf '\n[General]\nDeviceID = bluetooth:004C:0000:0000\n' | sudo tee -a "$BLUETOOTH_CONF" >/dev/null
    fi
    ok "DeviceID Apple dans $BLUETOOTH_CONF"
  fi
  if ((!had_device_id)); then
    if can_sudo && sudo systemctl restart bluetooth; then
      ok "bluetooth redémarré"
      # The plugin keeps its widget visible until the first reconnect
      mkdir -p "$HOME/.local/state/omarchy"
      printf '{"waitingForFirstConnection":true}\n' >"$HOME/.local/state/omarchy/airpods-onboarding.json"
    else
      todo "AirPods : redémarre le bluetooth (sudo systemctl restart bluetooth)."
    fi
    todo "AirPods : oublie-les puis appaire-les de nouveau (Super+Ctrl+B) : le canal de contrôle ne s'ouvre que sur un appairage fait après le DeviceID Apple."
  fi

  if ! systemctl --user is-enabled airpods-tui >/dev/null 2>&1; then
    systemctl --user enable --now airpods-tui >/dev/null 2>&1 && ok "démon airpods-tui activé" ||
      warn "impossible d'activer le démon : systemctl --user enable --now airpods-tui"
  fi
}
