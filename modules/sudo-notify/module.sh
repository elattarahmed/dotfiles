# A notification when sudo waits for the password or the fingerprint in a
# terminal, from a pam_exec line at the top of /etc/pam.d/sudo. pacman lists
# that file as a backup file: sudo updates keep the change (and leave a
# .pacnew). Polkit prompts already have their own window.
# Item: sudo-notify

SUDO_NOTIFY_BIN=/usr/local/lib/dotfiles/sudo-auth-notify
# optional: if the script is missing or fails, sudo goes on as usual
SUDO_NOTIFY_PAM="auth      optional   pam_exec.so quiet $SUDO_NOTIFY_BIN"

module_sudo_notify() {
  local src="$DOTFILES_DIR/modules/sudo-notify/sudo-auth-notify"
  local pam=/etc/pam.d/sudo tmp

  if selected sudo-notify; then
    info "Notification quand sudo attend"
    is_live || return 0
    if cmp -s "$src" "$SUDO_NOTIFY_BIN" && grep -qF "$SUDO_NOTIFY_BIN" "$pam"; then
      ok "déjà en place"
      return 0
    fi
    if ! can_sudo; then
      todo "Notification de sudo : relance ./install.sh dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    # A copy owned by root, not a link: it runs as root.
    sudo install -D -m 755 -o root -g root "$src" "$SUDO_NOTIFY_BIN"
    ok "$SUDO_NOTIFY_BIN"
    if ! grep -qF "$SUDO_NOTIFY_BIN" "$pam"; then
      backup "$pam"
      tmp=$(mktemp)
      # Above the first auth line, so it runs before the fingerprint and
      # password prompts
      awk -v line="$SUDO_NOTIFY_PAM" \
        '!done && /^[[:space:]]*-?auth[[:space:]]/ { print line; done = 1 } { print }' "$pam" >"$tmp"
      sudo install -m 644 -o root -g root "$tmp" "$pam"
      rm -f "$tmp"
      ok "$pam"
    fi
  elif [[ -e $SUDO_NOTIFY_BIN ]] || grep -qF "$SUDO_NOTIFY_BIN" "$pam" 2>/dev/null; then
    info "Notification quand sudo attend"
    is_live || return 0
    if ! can_sudo; then
      todo "Notification de sudo à retirer : relance ./install.sh dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    if grep -qF "$SUDO_NOTIFY_BIN" "$pam"; then
      backup "$pam"
      tmp=$(mktemp)
      grep -vF "$SUDO_NOTIFY_BIN" "$pam" >"$tmp"
      sudo install -m 644 -o root -g root "$tmp" "$pam"
      rm -f "$tmp"
    fi
    sudo rm -f "$SUDO_NOTIFY_BIN"
    sudo rmdir --ignore-fail-on-non-empty "$(dirname "$SUDO_NOTIFY_BIN")"
    ok "notification de sudo retirée"
  fi
}
