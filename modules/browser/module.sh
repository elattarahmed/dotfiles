# Brave as the default browser. Omarchy then hands links to the Brave already
# running (a new tab there) instead of starting another browser.
# Item: browser-brave

module_browser() {
  selected browser-brave || return 0
  info "Navigateur"
  is_live || return 0
  if ! command -v brave >/dev/null; then
    omarchy install browser brave
  fi
  if [[ $(omarchy-cmd-default-browser 2>/dev/null) == brave-browser.desktop ]]; then
    ok "Brave déjà navigateur par défaut"
  elif omarchy default browser brave >/dev/null 2>&1; then
    ok "Brave navigateur par défaut"
  else
    warn "impossible de mettre Brave par défaut (omarchy default browser brave)"
  fi
}
