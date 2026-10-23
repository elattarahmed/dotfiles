# Screensaver text: "V3ry_B4d" in two styles that take turns, one per effect.
# Item: screensaver

module_screensaver() {
  local dir="$DOTFILES_DIR/modules/screensaver"
  local branding="$HOME/.config/omarchy/branding"
  local bin="$HOME/.local/bin/screensaver-rotate"
  local unit="$HOME/.config/systemd/user/screensaver-rotate.service"

  if selected screensaver; then
    info "Économiseur d'écran"
    pkg_add inotify-tools
    install_dir "$dir/texts" "$branding/screensaver.d"
    install_file "$dir/screensaver-rotate" "$bin" 755
    install_file "$dir/screensaver-rotate.service" "$unit"
    # The first text right away, in case the service can't run yet
    install_file "$branding/screensaver.d/$(ls "$branding/screensaver.d" | head -1)" "$branding/screensaver.txt"
    if is_live; then
      systemctl --user daemon-reload
      if systemctl --user enable screensaver-rotate >/dev/null 2>&1; then
        [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && systemctl --user restart screensaver-rotate
        ok "service screensaver-rotate activé"
      fi
    fi
  elif [[ -f $unit ]]; then
    if is_live; then
      systemctl --user disable --now screensaver-rotate >/dev/null 2>&1 || true
    fi
    rm -f "$unit" "$bin"
    rm -rf "$branding/screensaver.d"
    install_file "${OMARCHY_PATH:-/usr/share/omarchy}/logo.txt" "$branding/screensaver.txt"
    ok "économiseur rendu à Omarchy"
  fi
}
