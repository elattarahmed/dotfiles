# The guide (GUIDE.md) and the dotfiles-guide command that shows it. Always
# installed: it is how the rest gets explained.

module_guide() {
  install_file "$DOTFILES_DIR/GUIDE.md" "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/GUIDE.md"
  install_file "$DOTFILES_DIR/modules/guide/dotfiles-guide" "$HOME/.local/bin/dotfiles-guide" 755
}
