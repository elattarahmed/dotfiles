# Omarchy theme. Omarchy's own command switches everything at once (terminal,
# bar, lock screen, wallpaper…).
# Item: theme

THEME_NAME="Hackerman"

module_theme() {
  selected theme || return 0
  info "Thème"
  is_live || return 0
  if [[ $(omarchy theme current 2>/dev/null) == "$THEME_NAME" ]]; then
    ok "thème $THEME_NAME déjà actif"
  elif omarchy theme set "$THEME_NAME" >/dev/null 2>&1; then
    ok "thème $THEME_NAME"
  else
    warn "impossible d'appliquer le thème $THEME_NAME (omarchy theme list)"
  fi
}
