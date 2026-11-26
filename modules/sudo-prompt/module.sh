# A small window, like Omarchy's polkit dialog, while sudo waits in a
# terminal: "touch the fingerprint sensor" with a countdown, then "type your
# password in the terminal", then a check mark once sudo is authorized (or a
# cross). It takes neither the keyboard nor the mouse.
#
# Three optional pam_exec lines in /etc/pam.d/sudo run a root-owned script
# that drives the dotfiles.sudo-prompt shell plugin:
#   - before the first auth line: window opens on the fingerprint. It goes
#     above Omarchy's lid check too, which must stay right before pam_fprintd
#     (its [success=1] skips exactly the next line);
#   - right after pam_fprintd: the password, typed in the terminal;
#   - at the end, in the session stack: authorized.
# sudo can't read the password while pam_fprintd waits for a finger (PAM runs
# one module at a time), so pam_fprintd gets timeout=10 instead of its 30 s
# default, unless the line already sets one: without a finger, the password
# is asked after 10 s.
#
# Optional lines can never fail sudo. Before writing the file, the module
# checks that taking its changes back out gives the original exactly.
# Item: sudo-prompt

SUDO_PROMPT_BIN=/usr/local/lib/dotfiles/sudo-prompt
SUDO_PROMPT_PLUGIN=dotfiles.sudo-prompt
SUDO_PROMPT_START="auth      optional   pam_exec.so quiet $SUDO_PROMPT_BIN fingerprint"
SUDO_PROMPT_PASSWORD="auth      optional   pam_exec.so quiet $SUDO_PROMPT_BIN password"
SUDO_PROMPT_DONE="session   optional   pam_exec.so quiet $SUDO_PROMPT_BIN done"
SUDO_PROMPT_FP_TIMEOUT=10

# sudo_prompt_base FILE: FILE without this module's changes (stdout)
sudo_prompt_base() {
  grep -vF "$SUDO_PROMPT_BIN" "$1" |
    sed -E "/^[[:space:]]*auth[[:space:]].*pam_fprintd\\.so/ s/ timeout=$SUDO_PROMPT_FP_TIMEOUT\$//"
}

# sudo_prompt_pam FILE: FILE as it should be, with the three lines and the
# fingerprint timeout (stdout)
sudo_prompt_pam() {
  local base
  base=$(sudo_prompt_base "$1")
  awk -v start="$SUDO_PROMPT_START" -v pass="$SUDO_PROMPT_PASSWORD" -v done_line="$SUDO_PROMPT_DONE" \
    -v fp_timeout="$SUDO_PROMPT_FP_TIMEOUT" '
    /^[[:space:]]*auth[[:space:]].*pam_fprintd/ { fprintd = 1 }
    { lines[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        line = lines[i]
        if (!started && line ~ /^[[:space:]]*-?auth[[:space:]]/) { print start; started = 1 }
        # Without pam_fprintd, the password step comes right before the stack
        # that asks for it
        if (!passed && !fprintd && line ~ /^[[:space:]]*auth[[:space:]].*(include|substack)[[:space:]]/) { print pass; passed = 1 }
        is_fp = line ~ /^[[:space:]]*auth[[:space:]].*pam_fprintd/
        if (is_fp && line !~ /[[:space:]]timeout=/) line = line " timeout=" fp_timeout
        print line
        if (!passed && is_fp) { print pass; passed = 1 }
      }
      print done_line
    }' <<<"$base"
}

module_sudo_prompt() {
  local dir="$DOTFILES_DIR/modules/sudo-prompt"
  local plugin="$HOME/.config/omarchy/plugins/$SUDO_PROMPT_PLUGIN"
  local pam=/etc/pam.d/sudo tmp

  if selected sudo-prompt; then
    info "Fenêtre sudo (empreinte / mot de passe)"
    install_dir "$dir/plugin" "$plugin"
    enable_plugin "$SUDO_PROMPT_PLUGIN"
    is_live || return 0
    tmp=$(mktemp)
    sudo_prompt_pam "$pam" >"$tmp"
    if cmp -s "$dir/sudo-prompt" "$SUDO_PROMPT_BIN" && cmp -s "$tmp" "$pam"; then
      rm -f "$tmp"
      ok "déjà en place"
      return 0
    fi
    if ! can_sudo; then
      rm -f "$tmp"
      todo "Fenêtre sudo : relance ./install.sh sudo-prompt dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    # A copy owned by root, not a link: it runs as root
    if ! cmp -s "$dir/sudo-prompt" "$SUDO_PROMPT_BIN"; then
      sudo install -D -m 755 -o root -g root "$dir/sudo-prompt" "$SUDO_PROMPT_BIN"
      ok "$SUDO_PROMPT_BIN"
    fi
    if ! cmp -s "$tmp" "$pam"; then
      if cmp -s <(sudo_prompt_base "$tmp") <(sudo_prompt_base "$pam") && [[ $(grep -cF "$SUDO_PROMPT_BIN" "$tmp") == 3 ]]; then
        backup "$pam"
        sudo install -m 644 -o root -g root "$tmp" "$pam"
        ok "$pam (3 lignes optional, empreinte : timeout=$SUDO_PROMPT_FP_TIMEOUT s)"
      else
        warn "$pam a une forme inattendue : rien n'y est changé, la fenêtre sudo ne s'ouvrira pas"
      fi
    fi
    rm -f "$tmp"
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
      sudo_prompt_base "$pam" >"$tmp"
      sudo install -m 644 -o root -g root "$tmp" "$pam"
      rm -f "$tmp"
    fi
    sudo rm -f "$SUDO_PROMPT_BIN"
    sudo rmdir --ignore-fail-on-non-empty "$(dirname "$SUDO_PROMPT_BIN")"
    ok "fenêtre sudo retirée"
  fi
}
