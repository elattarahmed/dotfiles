# Screensaver text: the same text drawn in several figlet fonts, one per
# effect. screensaver-text changes the text and the fonts (screensaver-text
# --help); the screensaver-rotate service swaps them in. The text itself stays
# on the machine, in ~/.config/dotfiles/screensaver.conf, never in this repo.
# Item: screensaver

module_screensaver() {
  local dir="$DOTFILES_DIR/modules/screensaver"
  local branding="$HOME/.config/omarchy/branding"
  local bin="$HOME/.local/bin"
  local unit="$HOME/.config/systemd/user/screensaver-rotate.service"
  local fonts="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/figlet"
  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/screensaver.conf"

  if selected screensaver; then
    info "Économiseur d'écran"
    pkg_add figlet inotify-tools
    aur_add figlet-fonts-extra
    install_file "$dir/screensaver-text" "$bin/screensaver-text" 755
    install_file "$dir/screensaver-rotate" "$bin/screensaver-rotate" 755
    install_file "$dir/screensaver-rotate.service" "$unit"
    local font
    for font in "$dir"/fonts/*.flf; do
      install_file "$font" "$fonts/$(basename "$font")"
    done

    if ! command -v figlet >/dev/null; then
      todo "Économiseur : installe figlet et figlet-fonts-extra, puis lance screensaver-text set \"Ton texte\"."
    elif [[ ! -f $conf ]]; then
      local text
      text=$(ask "Texte de l'économiseur d'écran :" "Omarchy")
      "$dir/screensaver-text" set "${text:-Omarchy}" >/dev/null && ok "économiseur : « ${text:-Omarchy} » (screensaver-text pour le changer)"
    else
      "$dir/screensaver-text" generate --quiet && ok "économiseur redessiné depuis $(pretty "$conf")"
    fi

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
    rm -rf "$unit" "$bin/screensaver-rotate" "$bin/screensaver-text" "$fonts" "$branding/screensaver.d"
    install_file "${OMARCHY_PATH:-/usr/share/omarchy}/logo.txt" "$branding/screensaver.txt"
    ok "économiseur rendu à Omarchy (ta config reste dans $(pretty "$conf"))"
  fi
}
