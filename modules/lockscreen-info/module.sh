# Lock screen with the time, the date, the battery and the music playing.
#
# Omarchy's lock screen is a Quickshell plugin (omarchy.lock). This module
# builds a clone of it (<user>.lock, like `omarchy plugin clone omarchy.lock`)
# from the copy Omarchy ships *now*, adds LockExtras.qml and one line in
# LockView.qml to show it, and nothing else: the lock service (session lock,
# PAM, fingerprint) stays Omarchy's own code. Re-run ./install.sh after an
# Omarchy update to pick up its changes to the lock screen.
# Item: lockscreen-info

LOCK_SOURCE_ID=omarchy.lock

lock_clone_id() { echo "${USER:-$(id -un)}.lock"; }

# The line LockExtras goes in front of: the wake-on-mouse area, drawn after
# the blurred wallpaper. Being in front of it keeps clicks reaching it.
LOCK_ANCHOR='    MouseArea {'

# build_lock_clone DIR: write the patched clone into DIR. Fails (without
# touching anything installed) when Omarchy's LockView changed too much.
build_lock_clone() {
  local stage=$1 src="${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/lock"
  local id view
  id=$(lock_clone_id)
  [[ -f $src/LockView.qml && -f $src/manifest.json ]] || return 1
  cp -aL "$src/." "$stage/"
  view="$stage/LockView.qml"
  [[ $(grep -cxF -- "$LOCK_ANCHOR" "$view") -ge 1 ]] || return 1
  awk -v anchor="$LOCK_ANCHOR" '
    !done && $0 == anchor {
      print "    // dotfiles (lockscreen-info): time, date, battery, music"
      print "    LockExtras { anchors.fill: parent; fieldHalfHeight: Math.round(root.fieldHeight / 2) }"
      print ""
      done = 1
    }
    { print }' "$view" >"$view.new" && mv "$view.new" "$view"
  cp "$DOTFILES_DIR/modules/lockscreen-info/LockExtras.qml" "$stage/LockExtras.qml"
  jq --arg id "$id" '
    .id = $id | .name = "My Lock Screen" |
    .omarchy = ((.omarchy // {}) + { clonedFrom: "omarchy.lock" }) | del(.omarchy.clonePaths)
  ' "$stage/manifest.json" >"$stage/manifest.json.new" && mv "$stage/manifest.json.new" "$stage/manifest.json"
}

module_lockscreen_info() {
  local id dest stage
  id=$(lock_clone_id)
  dest="$HOME/.config/omarchy/plugins/$id"

  if selected lockscreen-info; then
    info "Écran de verrouillage : heure, batterie, musique"
    stage=$(mktemp -d)
    if ! build_lock_clone "$stage"; then
      rm -rf "$stage"
      warn "l'écran de verrouillage d'Omarchy a changé : le dotfile ne sait plus s'y greffer, l'écran d'origine reste"
      return 0
    fi
    # A copy, never a link: it is rebuilt from Omarchy's current lock screen
    LINK=0 install_dir "$stage" "$dest"
    rm -rf "$stage"
    enable_plugin "$id"
    is_live && todo "Écran de verrouillage : aperçu sans verrouiller avec omarchy-shell lock preview (un clic le ferme)."
  elif [[ -d $dest ]] && grep -qs '"clonedFrom": *"omarchy.lock"' "$dest/manifest.json" && [[ -f $dest/LockExtras.qml ]]; then
    info "Écran de verrouillage : heure, batterie, musique"
    is_live && { omarchy plugin enable "$LOCK_SOURCE_ID" >/dev/null 2>&1 || true; }
    disable_plugin "$id"
    backup "$dest"
    rm -rf "$dest"
    is_live && { omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true; }
    ok "écran de verrouillage d'Omarchy rétabli"
  fi
}
