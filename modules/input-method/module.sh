# On Omarchy fcitx5 only serves Compose sequences (~/.XCompose), but as an
# input method it sits between the keyboard and every app: in Ghostty it ate
# Shift + arrows (a stray C or D instead of a selection). Turn it off and let
# the apps handle dead keys (^ ¨) and Compose themselves.
# Item: no-fcitx

module_input_method() {
  local service=omarchy-fcitx5
  local src="$DOTFILES_DIR/modules/input-method/10-omarchy-fcitx.conf"
  # Same name as Omarchy's /usr/lib/environment.d file, so this one wins
  local env_file="$HOME/.config/environment.d/10-omarchy-fcitx.conf"

  if selected no-fcitx; then
    info "Méthode de saisie : sans fcitx5"
    install_file "$src" "$env_file"
    if is_live; then
      systemctl --user disable --now "$service" >/dev/null 2>&1 || true
      if systemctl --user mask "$service" >/dev/null 2>&1; then
        ok "fcitx5 désactivé"
      fi
      # Apps launched from now on; a new session applies it everywhere
      systemctl --user set-environment GTK_IM_MODULE=simple QT_IM_MODULE=compose \
        INPUT_METHOD= XMODIFIERS= SDL_IM_MODULE=
      todo "se déconnecter puis se reconnecter pour que toutes les applis gèrent ^ et ¨ sans fcitx5"
    fi
  elif [[ -f $env_file ]] && cmp -s "$src" "$env_file"; then
    info "Méthode de saisie : fcitx5 rétabli"
    rm -f "$env_file"
    ok "$(pretty "$env_file") supprimé"
    if is_live; then
      systemctl --user unmask "$service" >/dev/null 2>&1 || true
      if systemctl --user enable --now "$service" >/dev/null 2>&1; then
        ok "fcitx5 réactivé"
      fi
      todo "se déconnecter puis se reconnecter pour revenir à fcitx5 partout"
    fi
  fi
}
