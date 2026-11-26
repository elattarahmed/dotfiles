# A small window, like Omarchy's polkit dialog, while sudo waits in a
# terminal: "touch the fingerprint sensor", then "type your password in the
# terminal", then a check mark once sudo is authorized (or a cross).
#
# Three optional pam_exec lines in /etc/pam.d/sudo run a root-owned script
# that drives the dotfiles.sudo-prompt shell plugin:
#   - before the first auth line: window opens on the fingerprint. It goes
#     above Omarchy's lid check too, which must stay right before pam_fprintd
#     (its [success=1] skips exactly the next line);
#   - right after pam_fprintd: the password, typed in the terminal;
#   - at the end, in the session stack: authorized.
# Optional lines can never fail sudo. Before writing the file, the module
# checks that removing its lines gives back the original exactly.
# Item: sudo-prompt

SUDO_PROMPT_BIN=/usr/local/lib/dotfiles/sudo-prompt
SUDO_PROMPT_PLUGIN=dotfiles.sudo-prompt
SUDO_PROMPT_START="auth      optional   pam_exec.so quiet $SUDO_PROMPT_BIN fingerprint"
SUDO_PROMPT_PASSWORD="auth      optional   pam_exec.so quiet $SUDO_PROMPT_BIN password"
SUDO_PROMPT_DONE="session   optional   pam_exec.so quiet $SUDO_PROMPT_BIN done"

# sudo_prompt_pam FILE: FILE with the three lines added (stdout)
sudo_prompt_pam() {
  awk -v start="$SUDO_PROMPT_START" -v pass="$SUDO_PROMPT_PASSWORD" -v done_line="$SUDO_PROMPT_DONE" '
    !started && /^[[:space:]]*-?auth[[:space:]]/ { print start; started = 1 }
    # Without pam_fprintd, the password step comes right before the stack
    # that asks for it
    !passed && !fprintd && /^[[:space:]]*auth[[:space:]].*(include|substack)[[:space:]]/ { print pass; passed = 1 }
    { print }
    !passed && /^[[:space:]]*auth[[:space:]].*pam_fprintd/ { print pass; passed = 1 }
    END { print done_line }
  ' fprintd="$(grep -cE '^[[:space:]]*auth[[:space:]].*pam_fprintd' "$1")" "$1"
}

module_sudo_prompt() {
  local dir="$DOTFILES_DIR/modules/sudo-prompt"
  local plugin="$HOME/.config/omarchy/plugins/$SUDO_PROMPT_PLUGIN"
  local pam=/etc/pam.d/sudo tmp clean

  if selected sudo-prompt; then
    info "Fenêtre sudo (empreinte / mot de passe)"
    install_dir "$dir/plugin" "$plugin"
    enable_plugin "$SUDO_PROMPT_PLUGIN"
    is_live || return 0
    if cmp -s "$dir/sudo-prompt" "$SUDO_PROMPT_BIN" && grep -qF "$SUDO_PROMPT_BIN" "$pam"; then
      ok "déjà en place"
      return 0
    fi
    if ! can_sudo; then
      todo "Fenêtre sudo : relance ./install.sh sudo-prompt dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    # A copy owned by root, not a link: it runs as root
    sudo install -D -m 755 -o root -g root "$dir/sudo-prompt" "$SUDO_PROMPT_BIN"
    ok "$SUDO_PROMPT_BIN"
    if ! grep -qF "$SUDO_PROMPT_BIN" "$pam"; then
      tmp=$(mktemp)
      clean=$(mktemp)
      sudo_prompt_pam "$pam" >"$tmp"
      grep -vF "$SUDO_PROMPT_BIN" "$tmp" >"$clean" || true
      if cmp -s "$clean" "$pam" && [[ $(grep -cF "$SUDO_PROMPT_BIN" "$tmp") == 3 ]]; then
        backup "$pam"
        sudo install -m 644 -o root -g root "$tmp" "$pam"
        ok "$pam (3 lignes optional)"
      else
        warn "$pam a une forme inattendue : rien n'y est ajouté, la fenêtre sudo ne s'ouvrira pas"
      fi
      rm -f "$tmp" "$clean"
    fi
  elif [[ -d $plugin || -e $SUDO_PROMPT_BIN ]] || grep -qsF "$SUDO_PROMPT_BIN" "$pam"; then
    info "Fenêtre sudo (empreinte / mot de passe)"
    disable_plugin "$SUDO_PROMPT_PLUGIN"
    rm -rf "$plugin"
    is_live || return 0
    if ! can_sudo; then
      todo "Fenêtre sudo à retirer : relance ./install.sh dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    if grep -qF "$SUDO_PROMPT_BIN" "$pam"; then
      backup "$pam"
      tmp=$(mktemp)
      grep -vF "$SUDO_PROMPT_BIN" "$pam" >"$tmp"
      sudo install -m 644 -o root -g root "$tmp" "$pam"
      rm -f "$tmp"
    fi
    sudo rm -f "$SUDO_PROMPT_BIN"
    sudo rmdir --ignore-fail-on-non-empty "$(dirname "$SUDO_PROMPT_BIN")"
    ok "fenêtre sudo retirée"
  fi
}
