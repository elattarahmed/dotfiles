# Session restore: the windows open when the machine went off (apps, Ghostty
# windows and their tabs, with their folders) reopen at the next login, each on
# its workspace and at its place. dotfiles-session keeps the snapshot; the
# zshrc lets each Ghostty tab say which window it is in.
# Item: session-restore

module_session() {
  local dir="$DOTFILES_DIR/modules/session"
  local bin="$HOME/.local/bin/dotfiles-session"
  local unit="$HOME/.config/systemd/user/dotfiles-session.service"

  if ! selected session-restore; then
    if [[ -f $unit ]]; then
      is_live && systemctl --user disable --now dotfiles-session >/dev/null 2>&1 || true
      rm -f "$unit" "$bin"
      ok "service dotfiles-session retiré"
    fi
    return 0
  fi
  info "Session : les fenêtres et onglets rouverts à la connexion, à leur place"

  install_file "$dir/dotfiles-session" "$bin" 755
  install_file "$dir/dotfiles-session.service" "$unit"

  if is_live; then
    systemctl --user daemon-reload
    if systemctl --user enable dotfiles-session >/dev/null 2>&1; then
      # Restarted inside the same Hyprland it reopens nothing: it only saves
      [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && systemctl --user restart dotfiles-session
      ok "service dotfiles-session activé"
    fi
    selected zsh || todo "Session : sans l'élément zsh, les onglets Ghostty se rouvrent tous dans ton dossier personnel."
    todo "Session : dans Brave, Paramètres → Au démarrage → « Reprendre là où je me suis arrêté », pour retrouver aussi ses onglets."
  fi
}
