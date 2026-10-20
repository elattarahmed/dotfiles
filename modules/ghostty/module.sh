# Ghostty as the default terminal, with its shortcuts in included files so
# Omarchy's own ~/.config/ghostty/config stays as shipped.
# Items: ghostty, ghostty-tabs (and the terminal half of zsh-selection)

module_ghostty() {
  local dir="$DOTFILES_DIR/modules/ghostty"
  local config="$HOME/.config/ghostty/config"
  local include="$HOME/.config/ghostty/dotfiles"

  if selected ghostty; then
    info "Ghostty"
    if is_live && { ! command -v ghostty >/dev/null || ! grep -qx 'com.mitchellh.ghostty.desktop' <(grep -v '^#' "$HOME/.config/xdg-terminals.list" 2>/dev/null | head -1); }; then
      omarchy install terminal ghostty
    fi
  fi

  # Shortcuts apply wherever Ghostty is set up, chosen as default here or not
  if ! selected ghostty && ! command -v ghostty >/dev/null && [[ ! -f $config ]]; then
    return 0
  fi
  selected ghostty || info "Ghostty"

  [[ -f $config ]] || install_file "${OMARCHY_PATH:-/usr/share/omarchy}/config/ghostty/config" "$config"
  ensure_block "$config" "config-file = ?dotfiles/tabs.conf" "# Shortcuts from the dotfiles repo (./install.sh --disable ghostty-tabs to drop one)
config-file = ?dotfiles/tabs.conf
config-file = ?dotfiles/selection.conf"

  local feature item
  for feature in tabs:ghostty-tabs selection:zsh-selection; do
    item=${feature#*:}
    feature=${feature%%:*}
    if selected "$item"; then
      install_file "$dir/$feature.conf" "$include/$feature.conf"
    elif [[ -f $include/$feature.conf ]]; then
      backup "$include/$feature.conf"
      rm -f "$include/$feature.conf"
      ok "$(pretty "$include/$feature.conf") supprimé"
    fi
  done

  # Running Ghostty windows reload their config on SIGUSR2
  is_live && pkill -USR2 -x ghostty 2>/dev/null || true
}
