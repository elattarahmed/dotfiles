# The Interstellar waybar rice, on Omarchy's own bar: its colors for the bar,
# its popups and the notifications (the theme stays as it is), its VPN and IP
# modules (the public address, the local one in the tooltip), and the active
# window title.
# Item: interstellar-bar

INTERSTELLAR_SCRIPTS="$HOME/.config/omarchy/bar/scripts"
# Custom command modules, in shell.json's bar layout; the interstellar- prefix
# is how this module finds its own entries again
INTERSTELLAR_ENTRIES='[
  {"id": "interstellar-vpn", "type": "command", "exec": "~/.config/omarchy/bar/scripts/vpn-status", "interval": 10},
  {"id": "interstellar-ip", "type": "command", "exec": "~/.config/omarchy/bar/scripts/ip", "interval": 30,
   "onClick": "~/.config/omarchy/bar/scripts/ip --copy", "onRightClick": "~/.config/omarchy/bar/scripts/ip --copy-local"}
]'
# Earlier entries, replaced by interstellar-ip
INTERSTELLAR_OLD='["interstellar-local-ip", "interstellar-public-ip"]'

# edit_shell_json JQ_PROGRAM [jq args...]: rewrite shell.json in place (the
# shell watches it and reloads), only when the program changes something
edit_shell_json() {
  local file="$HOME/.config/omarchy/shell.json" tmp
  [[ -f $file ]] || return 0
  tmp=$(mktemp)
  if jq "$@" "$file" >"$tmp" && ! cmp -s "$tmp" "$file"; then
    backup "$file"
    cat "$tmp" >"$file"
    ok "$(pretty "$file")"
  fi
  rm -f "$tmp"
}

module_interstellar_bar() {
  local dir="$DOTFILES_DIR/modules/interstellar-bar"

  if ! selected interstellar-bar; then
    is_live || return 0
    edit_shell_json '.bar.layout |= map_values(map(select(.id | startswith("interstellar-") | not)))'
    [[ -L $HOME/.config/omarchy/shell.toml && $(readlink "$HOME/.config/omarchy/shell.toml") == "$dir/shell.toml" ]] &&
      rm "$HOME/.config/omarchy/shell.toml" && ok "couleurs du thème rendues à la barre"
    return 0
  fi
  info "Barre Interstellar"

  install_file "$dir/shell.toml" "$HOME/.config/omarchy/shell.toml"
  local script
  for script in vpn-status ip; do
    install_file "$dir/scripts/$script" "$INTERSTELLAR_SCRIPTS/$script" 755
  done
  for script in local-ip public-ip; do
    [[ -f $INTERSTELLAR_SCRIPTS/$script ]] && rm -f "$INTERSTELLAR_SCRIPTS/$script" && ok "$(pretty "$INTERSTELLAR_SCRIPTS/$script") retiré (remplacé par ip)"
  done

  is_live || return 0
  omarchy bar put omarchy.active-window --after omarchy.workspaces >/dev/null 2>&1 || true
  # The rice's bar is opaque (92 %), not transparent like bar-layout's
  omarchy bar transparent false >/dev/null 2>&1 || true
  edit_shell_json --argjson old "$INTERSTELLAR_OLD" '.bar.layout |= map_values(map(select(.id as $id | $old | index($id) | not)))'
  # Before RAM / CPU / temperature, like in the waybar
  edit_shell_json --argjson new "$INTERSTELLAR_ENTRIES" '
    [.bar.layout[]?[]?.id] as $ids
    | ($new | map(select(.id as $id | $ids | index($id) | not))) as $add
    | if ($add | length) == 0 then . else
        .bar.layout.right |= ((. // []) as $right
          | ($right | map(.id) | index("dotfiles.sysstats")) as $at
          | if $at == null then $add + $right else $right[:$at] + $add + $right[$at:] end)
      end'
}
