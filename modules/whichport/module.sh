# whichport (https://github.com/elattarahmed/whichport): built from source into
# ~/.local/bin, plus its bar widget and floating window.
# Item: whichport

WHICHPORT_REPO=https://github.com/elattarahmed/whichport.git

module_whichport() {
  local plugin="$HOME/.config/omarchy/plugins/elattarahmed.whichport"
  if ! selected whichport; then
    disable_plugin elattarahmed.whichport
    return 0
  fi
  info "whichport"

  if is_live && ! [[ -x $HOME/.local/bin/whichport ]] && ! command -v whichport >/dev/null; then
    pkg_add go git make
    local src
    src=$(mktemp -d)
    if git clone --quiet --depth 1 "$WHICHPORT_REPO" "$src" &&
      mkdir -p "$HOME/.local/bin" &&
      make -C "$src" --no-print-directory install PREFIX="$HOME/.local" >/dev/null; then
      ok "$(pretty "$HOME/.local/bin/whichport")"
    else
      warn "la compilation de whichport a échoué (voir $WHICHPORT_REPO)"
    fi
    rm -rf "$src"
  fi

  # The widget ships in the whichport repo too; this copy works until it's merged there
  install_dir "$DOTFILES_DIR/modules/whichport/plugin" "$plugin"
  enable_plugin elattarahmed.whichport --section right --index 0
}
