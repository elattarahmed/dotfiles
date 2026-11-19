# Idle: the screensaver after IDLE_SCREENSAVER seconds, the password asked as
# soon as you come back from it (screensaver-lock service), and the session
# locked with the screen off after IDLE_BLANK seconds (Omarchy's idle.lock:
# its lock screen turns the displays off 5 s after locking).
# Item: idle-lock

IDLE_SCREENSAVER=300   # 5 min
IDLE_BLANK=900         # 15 min

module_idle() {
  local dir="$DOTFILES_DIR/modules/idle"
  local bin="$HOME/.local/bin/screensaver-lock"
  local unit="$HOME/.config/systemd/user/screensaver-lock.service"
  local shell_json="$HOME/.config/omarchy/shell.json"

  if ! selected idle-lock; then
    if [[ -f $unit ]]; then
      is_live && systemctl --user disable --now screensaver-lock >/dev/null 2>&1 || true
      rm -f "$unit" "$bin"
      ok "service screensaver-lock retiré (délais d'Omarchy dans $(pretty "$shell_json") inchangés)"
    fi
    return 0
  fi
  info "Veille : économiseur à $((IDLE_SCREENSAVER / 60)) min · mot de passe au retour · écran noir à $((IDLE_BLANK / 60)) min"

  install_file "$dir/screensaver-lock" "$bin" 755
  install_file "$dir/screensaver-lock.service" "$unit"

  if [[ -f $shell_json ]]; then
    if [[ $(jq -c '[.idle.screensaver, .idle.lock]' "$shell_json" 2>/dev/null) != "[$IDLE_SCREENSAVER,$IDLE_BLANK]" ]]; then
      jq --argjson s "$IDLE_SCREENSAVER" --argjson l "$IDLE_BLANK" '.idle.screensaver = $s | .idle.lock = $l' "$shell_json" |
        write_file "$shell_json"
      # The shell rereads shell.json at once, but its idle monitor keeps the
      # delay it started with: changed live, it never reported idle again.
      if is_live && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        omarchy restart shell >/dev/null 2>&1 && ok "shell Omarchy redémarré (nouveaux délais)" ||
          relogin "les nouveaux délais de veille s'appliquent (le shell Omarchy ne les lit qu'à son démarrage)"
      fi
    fi
  else
    todo "Veille : pas de $(pretty "$shell_json"), mets idle.screensaver à $IDLE_SCREENSAVER et idle.lock à $IDLE_BLANK."
  fi

  if is_live; then
    systemctl --user daemon-reload
    if systemctl --user enable screensaver-lock >/dev/null 2>&1; then
      [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && systemctl --user restart screensaver-lock
      ok "service screensaver-lock activé"
    fi
  fi
}
