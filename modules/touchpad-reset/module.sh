# A touchpad that believes fingers are still on it after a long pause
# (moving scrolls, scrolling zooms): SUPER + CTRL + ALT + P resets it
# (hypr/dotfiles/touchpad_reset.lua), and it is reset after every resume.
#
# The reset unbinds and binds the touchpad's i2c-hid driver again, as root,
# through a fixed script that takes no argument: sudoers lets the user run
# that one script without a password, so the shortcut works without a prompt.
# Without it (--files-only, or not installed yet), touchpad-reset falls back
# to turning the touchpad off and on in Hyprland.
# Item: touchpad-reset

TOUCHPAD_REBIND=/usr/local/lib/dotfiles/touchpad-rebind
TOUCHPAD_SUDOERS=/etc/sudoers.d/dotfiles-touchpad-reset
TOUCHPAD_SLEEP_HOOK=/usr/lib/systemd/system-sleep/dotfiles-touchpad-reset

touchpad_sleep_hook() {
  cat <<EOF
#!/bin/sh
# From the dotfiles (touchpad-reset): after resume, reset the touchpad so it
# doesn't come back believing fingers are still on it.
[ "\$1" = post ] && exec $TOUCHPAD_REBIND
exit 0
EOF
}

touchpad_sudoers() {
  printf '# From the dotfiles (touchpad-reset): reset the touchpad without a password\n'
  printf '%s ALL=(root) NOPASSWD: %s\n' "$USER" "$TOUCHPAD_REBIND"
}

# sudo_install_text DEST MODE: install stdin as root-owned DEST if it differs
sudo_install_text() {
  local dest=$1 mode=$2 tmp
  tmp=$(mktemp)
  cat >"$tmp"
  if sudo cmp -s "$tmp" "$dest" 2>/dev/null; then
    rm -f "$tmp"
    return 0
  fi
  sudo install -D -m "$mode" -o root -g root "$tmp" "$dest"
  rm -f "$tmp"
  ok "$dest"
}

touchpad_system_files_current() {
  cmp -s "$DOTFILES_DIR/modules/touchpad-reset/touchpad-rebind" "$TOUCHPAD_REBIND" &&
    cmp -s <(touchpad_sleep_hook) "$TOUCHPAD_SLEEP_HOOK" &&
    # /etc/sudoers.d isn't readable by the user: ask sudo whether the script
    # runs without a password instead
    sudo -n -l "$TOUCHPAD_REBIND" >/dev/null 2>&1
}

module_touchpad_reset() {
  local dir="$DOTFILES_DIR/modules/touchpad-reset"
  local bin="$HOME/.local/bin/touchpad-reset"

  if selected touchpad-reset; then
    info "Pavé tactile : réinitialisation"
    install_file "$dir/touchpad-reset" "$bin" 755
    is_live || return 0
    if touchpad_system_files_current; then
      ok "réinitialisation sans mot de passe et après la veille déjà en place"
      return 0
    fi
    if ! can_sudo; then
      todo "Pavé tactile : relance ./install.sh touchpad-reset dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    # Copies owned by root, not links: they run as root.
    sudo install -D -m 755 -o root -g root "$dir/touchpad-rebind" "$TOUCHPAD_REBIND"
    ok "$TOUCHPAD_REBIND"
    touchpad_sleep_hook | sudo_install_text "$TOUCHPAD_SLEEP_HOOK" 755

    local tmp
    tmp=$(mktemp)
    touchpad_sudoers >"$tmp"
    if sudo visudo -cqf "$tmp"; then
      touchpad_sudoers | sudo_install_text "$TOUCHPAD_SUDOERS" 440
    else
      warn "règle sudoers refusée par visudo : Super+Ctrl+Alt+P fera seulement la réinitialisation légère"
    fi
    rm -f "$tmp"
  else
    if [[ -f $bin ]] && cmp -s "$dir/touchpad-reset" "$bin"; then
      rm -f "$bin"
      ok "touchpad-reset retiré"
    fi
    is_live || return 0
    # The sudoers rule can't be seen from here; it comes and goes with the script
    [[ -e $TOUCHPAD_REBIND || -e $TOUCHPAD_SLEEP_HOOK ]] || return 0
    info "Pavé tactile : réinitialisation"
    if ! can_sudo; then
      todo "Réinitialisation du pavé tactile à retirer : relance ./install.sh dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    sudo rm -f "$TOUCHPAD_SUDOERS" "$TOUCHPAD_SLEEP_HOOK" "$TOUCHPAD_REBIND"
    sudo rmdir --ignore-fail-on-non-empty "$(dirname "$TOUCHPAD_REBIND")"
    ok "réinitialisation du pavé tactile retirée"
  fi
}
