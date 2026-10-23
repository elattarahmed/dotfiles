# Boot screen (Plymouth, where the disk password is typed) in Matte Black's
# colors, whatever the desktop theme. Omarchy's command rebuilds the boot image
# and asks for the sudo password.
# Item: plymouth

PLYMOUTH_THEME="matte-black"

module_plymouth() {
  selected plymouth || return 0
  info "Écran de démarrage"
  is_live || return 0
  if [[ $(omarchy plymouth current 2>/dev/null) == "$PLYMOUTH_THEME" ]]; then
    ok "écran de démarrage déjà en $PLYMOUTH_THEME"
  elif omarchy plymouth set by theme "$PLYMOUTH_THEME"; then
    ok "écran de démarrage en $PLYMOUTH_THEME (visible au prochain démarrage)"
  else
    warn "impossible d'appliquer $PLYMOUTH_THEME : omarchy plymouth set by theme $PLYMOUTH_THEME"
  fi
}
