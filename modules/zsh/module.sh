# zsh with Powerlevel10k as the login shell.
# Items: zsh, zsh-line-keys, zsh-selection, zsh-root

module_zsh() {
  selected zsh || return 0
  local dir="$DOTFILES_DIR/modules/zsh"
  info "zsh"

  pkg_add zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions
  aur_add zsh-theme-powerlevel10k-git

  install_file "$dir/zshrc" "$HOME/.zshrc"
  install_file "$dir/p10k.zsh" "$HOME/.p10k.zsh"
  write_file "$HOME/.config/zsh/dotfiles.zsh" <<EOF
# zsh features from the dotfiles repo. Set one to 0 to turn it off, then run
# \`exec zsh\`. ./install.sh --disable <item> does the same.
DOTFILES_ZSH_LINE_KEYS=$(selected zsh-line-keys && echo 1 || echo 0)  # zsh-line-keys: Ctrl/Alt + Backspace/Delete, Alt + arrows
DOTFILES_ZSH_SELECTION=$(selected zsh-selection && echo 1 || echo 0)  # zsh-selection: Shift + arrows select, Alt+A/C/X
EOF

  is_live || return 0

  if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]]; then
    if chsh -s /usr/bin/zsh; then
      todo "Déconnecte-toi puis reconnecte-toi : zsh sera ton shell dans les nouveaux terminaux."
    else
      warn "chsh a échoué, lance : chsh -s /usr/bin/zsh"
    fi
  fi

  if selected zsh-root; then
    # A copy, not a link: a link would let anything running as you change
    # what runs the next time a root shell opens.
    [[ $(getent passwd root | cut -d: -f7) == */zsh ]] || sudo chsh -s /usr/bin/zsh root
    sudo install -m 644 -o root -g root "$HOME/.zshrc" "$HOME/.p10k.zsh" /root/
    sudo install -D -m 644 -o root -g root "$HOME/.config/zsh/dotfiles.zsh" /root/.config/zsh/dotfiles.zsh
    ok "root : zsh avec la même config"
  fi
}
