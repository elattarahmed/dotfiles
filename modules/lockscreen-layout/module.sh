# Omarchy's lock screen reads keys through fcitx5, whose profile defaults to
# the US layout: set it to the session's layout (AZERTY password on AZERTY).
# Item: lockscreen-layout

module_lockscreen_layout() {
  selected lockscreen-layout || return 0
  # Without fcitx5 the lock screen reads keys in the session layout already
  selected no-fcitx && return 0
  info "Disposition clavier de l'écran de verrouillage"

  local layout="" variant=""
  if is_live && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    layout=$(hyprctl getoption input:kb_layout -j | jq -r '.str // empty')
    variant=$(hyprctl getoption input:kb_variant -j | jq -r '.str // empty')
  else
    layout=$(localectl status 2>/dev/null | sed -n 's/^ *X11 Layout: //p')
  fi
  # With several layouts ("fr,us"), the first is the one active at login
  layout=${layout%%,*}
  variant=${variant%%,*}
  if [[ -z $layout ]]; then
    warn "disposition clavier introuvable, rien de changé"
    return 0
  fi

  local im="keyboard-$layout${variant:+-$variant}"
  local profile="$HOME/.config/fcitx5/profile"
  if grep -qx "DefaultIM=$im" "$profile" 2>/dev/null; then
    ok "fcitx5 déjà en $im"
    return 0
  fi

  # fcitx5 writes its profile back when it exits, so stop it before editing.
  # Omarchy runs it as a user service that restarts it: never start a second copy.
  local service=omarchy-fcitx5
  if is_live; then
    if systemctl --user cat "$service" >/dev/null 2>&1; then
      systemctl --user stop "$service"
    else
      pkill -x fcitx5 && sleep 1 || true
    fi
  fi

  write_file "$profile" <<EOF
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=$layout${variant:+-$variant}
# Default Input Method
DefaultIM=$im

[Groups/0/Items/0]
# Name
Name=$im
# Layout
# Layout=

[GroupOrder]
0=Default

EOF

  if is_live; then
    if systemctl --user cat "$service" >/dev/null 2>&1; then
      systemctl --user start "$service"
    else
      (setsid fcitx5 -d >/dev/null 2>&1 &)
    fi
  fi
}
