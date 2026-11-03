# On Omarchy fcitx5 only serves Compose sequences (~/.XCompose), but as an
# input method it sits between the keyboard and every app: in Ghostty it ate
# Shift + arrows (a stray C or D instead of a selection). Turn it off and let
# the apps handle dead keys (^ ¨) and Compose themselves.
# Item: no-fcitx
#
# ligatures.XCompose adds AltGr+O/A then E for œ/æ (Shift for Œ/Æ). It is
# included from ~/.XCompose, which stays the user's own file.
# Item: ligatures

module_input_method() {
  input_method_fcitx
  input_method_ligatures
}

input_method_ligatures() {
  local src="$DOTFILES_DIR/modules/input-method/ligatures.XCompose"
  local dest="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ligatures.XCompose"
  local xcompose="$HOME/.XCompose"
  local include="include \"$dest\""
  local comment="# Joined letters from the dotfiles repo (./install.sh --disable ligatures to drop them)"
  local kept

  if selected ligatures; then
    info "Ligatures : AltGr+O puis E → œ · AltGr+A puis E → æ"
    install_file "$src" "$dest"
    ensure_block "$xcompose" "$include" "$comment
$include"
    is_live && todo "relancer les applis ouvertes pour qu'elles connaissent œ et æ (AltGr+O ou AltGr+A, puis E)"
  elif [[ -f $xcompose ]] && grep -qxF -- "$include" "$xcompose"; then
    info "Ligatures retirées"
    backup "$xcompose"
    # Drop exactly our two lines, keep the rest of the user's file
    kept=$(grep -vxF -e "$comment" -e "$include" "$xcompose" || true)
    printf '%s\n' "$kept" >"$xcompose"
    rm -f "$dest"
    ok "$(pretty "$xcompose")"
  fi
}

input_method_fcitx() {
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
