# On Omarchy fcitx5 only serves Compose sequences (~/.XCompose), but as an
# input method it sits between the keyboard and every app: in Ghostty it ate
# Shift + arrows (a stray C or D instead of a selection). Turn it off and let
# the apps handle dead keys (^ ¨) and Compose themselves.
# Item: no-fcitx
#
# xkb/ adds the dotfiles:oe keyboard option (AltGr+O types œ, AltGr+Shift+O Œ;
# AltGr+A is already æ on the French layout). The ligatures Hyprland feature
# turns the option on; Hyprland hands the keymap to every app.
# Item: ligatures

module_input_method() {
  input_method_fcitx
  input_method_ligatures
}

input_method_ligatures() {
  local src="$DOTFILES_DIR/modules/input-method/xkb"
  local xkb="${XDG_CONFIG_HOME:-$HOME/.config}/xkb"
  local file

  input_method_drop_old_compose

  if selected ligatures; then
    info "Ligatures : AltGr+O → œ · AltGr+A → æ (avec Maj : Œ Æ)"
    for file in rules/evdev symbols/dotfiles; do
      install_file "$src/$file" "$xkb/$file"
    done
    # hypr/dotfiles.lua was written before these files existed: rebuild the keymap
    if is_live && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
      hyprctl reload >/dev/null && ok "disposition clavier rechargée"
    fi
  else
    for file in rules/evdev symbols/dotfiles; do
      if [[ -L $xkb/$file && $(readlink "$xkb/$file") == "$src/$file" ]] ||
        { [[ -f $xkb/$file ]] && cmp -s "$src/$file" "$xkb/$file"; }; then
        rm -f "$xkb/$file"
        ok "$(pretty "$xkb/$file") supprimé"
      fi
    done
  fi
}

# The first version typed œ through a Compose sequence included from
# ~/.XCompose. It made AltGr+A wait for the next key, so remove it.
input_method_drop_old_compose() {
  local dest="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ligatures.XCompose"
  local xcompose="$HOME/.XCompose"
  local include="include \"$dest\""
  local comment="# Joined letters from the dotfiles repo (./install.sh --disable ligatures to drop them)"
  local kept

  [[ -L $dest || -f $dest ]] && rm -f "$dest"
  [[ -f $xcompose ]] && grep -qxF -- "$include" "$xcompose" || return 0
  backup "$xcompose"
  # Drop exactly those two lines, keep the rest of the user's file
  kept=$(grep -vxF -e "$comment" -e "$include" "$xcompose" || true)
  printf '%s\n' "$kept" >"$xcompose"
  ok "$(pretty "$xcompose") : ancienne séquence œ retirée"
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
