# Omarchy shell plugins and bar layout.
# Items: clipboard (history with pins + bar button), emojis, scale-button, resize-mode (its bar indicator), sysstats, bar-layout, privacy-indicator, audio-visualizer, pomodoro, dashboard

# install_plugin ID [placement...]: copy the plugin, then enable it. A plugin
# the shell keeps loaded (the clipboard picker) only picks up new code after
# a shell restart.
install_plugin() {
  local id=$1
  shift
  local src="$DOTFILES_DIR/modules/omarchy-plugins/$id" dest="$HOME/.config/omarchy/plugins/$id"
  local changed=0
  [[ -d $dest ]] && ! diff -rq "$src" "$dest" >/dev/null 2>&1 && changed=1
  install_dir "$src" "$dest"
  enable_plugin "$id" "$@"
  if ((changed)) && grep -q '"keepLoaded": true' "$src/manifest.json"; then
    RESTART_SHELL=1
  fi
}

module_omarchy_plugins() {
  local any=0 item
  for item in clipboard emojis scale-button resize-mode sysstats bar-layout privacy-indicator audio-visualizer pomodoro dashboard; do selected "$item" && any=1; done
  ((any)) && info "Barre et plugins Omarchy"

  # Each new widget goes first in the right section: the order ends up
  # whichport, clipboard, sysstats (whichport's module runs after this one).
  if selected sysstats; then
    install_plugin dotfiles.sysstats --section right --index 0
  else
    disable_plugin dotfiles.sysstats
  fi

  # Orange (microphone) / green (camera) dot, first on the right like macOS
  if selected privacy-indicator; then
    install_plugin dotfiles.privacy --section right --index 0
  else
    disable_plugin dotfiles.privacy
  fi

  # Bars moving with the music, next to the volume
  if selected audio-visualizer; then
    pkg_add cava
    install_plugin dotfiles.visualizer --before omarchy.audio
  else
    disable_plugin dotfiles.visualizer
  fi

  # The clock with its dashboard (calendar, weather, world clocks, pomodoro,
  # performances) takes the clock's place; what it holds leaves the bar
  if selected dashboard; then
    install_plugin dotfiles.dashboard --before omarchy.clock
    if is_live && [[ -f $HOME/.config/omarchy/shell.json ]]; then
      local shell_json=$HOME/.config/omarchy/shell.json tmp
      tmp=$(mktemp)
      jq '.bar.layout |= map_values(map(select(.id as $id | ["omarchy.clock", "omarchy.weather", "omarchy.elsewhen", "omarchy.indicators", "dotfiles.pomodoro"] | index($id) | not)))' \
        "$shell_json" >"$tmp"
      if ! cmp -s "$tmp" "$shell_json"; then
        backup "$shell_json"
        cat "$tmp" >"$shell_json"
        ok "horloge, météo, fuseaux, raccourcis et pomodoro rangés dans le tableau de bord"
      fi
      rm -f "$tmp"
    fi
  else
    if is_live && omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "dotfiles.dashboard" and .enabled)' >/dev/null; then
      omarchy bar put omarchy.clock --section center >/dev/null 2>&1 || true
    fi
    disable_plugin dotfiles.dashboard
  fi

  # Pomodoro timer next to the clock, unless the dashboard already has it
  if selected pomodoro && ! selected dashboard; then
    install_plugin dotfiles.pomodoro --section centerEnd --index 0
  else
    disable_plugin dotfiles.pomodoro
  fi

  if selected clipboard; then
    # A clone of omarchy.clipboard: enabling it replaces the built-in picker
    install_plugin dotfiles.clipboard
    install_plugin dotfiles.clipboard-button --section right --index 0
  else
    disable_plugin dotfiles.clipboard-button
    if is_live && omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "dotfiles.clipboard" and .enabled)' >/dev/null; then
      # Removing a clone switches back to Omarchy's own clipboard picker, which
      # saves the history again without the pins: keep a copy that has them
      backup "$HOME/.local/state/omarchy/clipboard-history.json"
      omarchy plugin remove dotfiles.clipboard --yes >/dev/null && ok "historique du presse-papiers d'Omarchy rétabli"
    fi
  fi

  # Goes first too: whichport, scale, clipboard, sysstats
  if selected scale-button; then
    install_plugin dotfiles.display-scale --section right --index 0
  else
    disable_plugin dotfiles.display-scale
  fi

  # Goes first too: whichport, resize, scale, clipboard, sysstats
  if selected resize-mode; then
    install_plugin dotfiles.resize-mode --section right --index 0
  else
    disable_plugin dotfiles.resize-mode
  fi

  if selected emojis; then
    # A clone of omarchy.emojis: its shortcuts (SUPER + CTRL + E, CTRL + ALT +
    # SPACE) open the clone once it is enabled
    install_plugin dotfiles.emojis
  elif is_live && omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "dotfiles.emojis" and .enabled)' >/dev/null; then
    omarchy plugin remove dotfiles.emojis --yes >/dev/null && ok "sélecteur d'émojis d'Omarchy rétabli"
  fi

  if selected bar-layout && is_live; then
    omarchy bar move omarchy.keyboard-layout --before omarchy.clock >/dev/null 2>&1 || true
    # Only while the network icon is in the bar itself: with bar-drawer it is
    # inside the tray's drawer, and the tray can't go after its own content
    if jq -e 'any(.bar.layout.right[]?; .id == "omarchy.network")' "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1; then
      omarchy bar move omarchy.tray --after omarchy.network >/dev/null 2>&1 || true
    fi
    # interstellar-bar wants the bar opaque
    if selected interstellar-bar; then
      ok "disposition de la barre"
    else
      omarchy bar transparent true >/dev/null 2>&1 || true
      ok "disposition de la barre (transparente)"
    fi
  fi

  if ((${RESTART_SHELL:-0})) && is_live; then
    omarchy restart shell >/dev/null 2>&1 && ok "shell Omarchy redémarré" || true
  fi
}
