# Part of the zoom item: a small user service that resets the screen zoom
# while the session is locked or the screensaver runs, and restores it after.
# Item: zoom

module_zoom_guard() {
  local dir="$DOTFILES_DIR/modules/zoom-guard"
  local bin="$HOME/.local/bin/zoom-lock-guard"
  local unit="$HOME/.config/systemd/user/zoom-lock-guard.service"

  if selected zoom; then
    info "Zoom : remis à zéro au verrouillage"
    install_file "$dir/zoom-lock-guard" "$bin" 755
    install_file "$dir/zoom-lock-guard.service" "$unit"
    if is_live; then
      systemctl --user daemon-reload
      if systemctl --user enable zoom-lock-guard >/dev/null 2>&1; then
        # Starts now only inside a Hyprland session (it needs its socket)
        [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && systemctl --user restart zoom-lock-guard
        ok "service zoom-lock-guard activé"
      fi
    fi
  elif [[ -f $unit ]]; then
    if is_live; then
      systemctl --user disable --now zoom-lock-guard >/dev/null 2>&1 || true
    fi
    rm -f "$unit" "$bin"
    ok "service zoom-lock-guard retiré"
  fi
}
