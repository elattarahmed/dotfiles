# Power profile: balanced. power-profiles-daemon remembers the last profile
# chosen, so a machine left on "performance" stays there on battery: the CPU
# keeps its top frequencies and the battery drains much faster. Balanced
# still lets the CPU boost when there is work to do.
# Item: power-profile

POWER_PROFILE=balanced

module_power_profile() {
  selected power-profile || return 0
  info "Profil d'énergie"
  is_live || return 0
  if ! command -v powerprofilesctl >/dev/null; then
    warn "powerprofilesctl introuvable (power-profiles-daemon) : profil inchangé"
    return 0
  fi
  local current
  current=$(powerprofilesctl get 2>/dev/null || true)
  if [[ $current == "$POWER_PROFILE" ]]; then
    ok "déjà en $POWER_PROFILE"
  elif powerprofilesctl set "$POWER_PROFILE"; then
    ok "$current → $POWER_PROFILE (gardé après redémarrage)"
  else
    warn "impossible de passer en $POWER_PROFILE : powerprofilesctl set $POWER_PROFILE"
  fi
}
