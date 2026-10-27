# zsh as the login shell, with a Powerlevel10k or starship prompt.
# Items: zsh, zsh-p10k, zsh-p10k-style, zsh-line-keys, zsh-selection, zsh-progress, zsh-root

module_zsh() {
  selected zsh || return 0
  local dir="$DOTFILES_DIR/modules/zsh"
  info "zsh"

  pkg_add zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions
  selected zsh-p10k && aur_add zsh-theme-powerlevel10k-git
  selected zsh-progress && aur_add advcpmv

  install_file "$dir/zshrc" "$HOME/.zshrc"
  # The repo's prompt style needs a Nerd Font, so it is opt-in. Otherwise an
  # existing ~/.p10k.zsh is kept, and without one Powerlevel10k's wizard asks
  # on the first zsh start (it checks which icons this machine can show).
  if selected zsh-p10k && selected zsh-p10k-style; then
    install_file "$dir/p10k.zsh" "$HOME/.p10k.zsh"
  elif selected zsh-p10k && [[ ! -f $HOME/.p10k.zsh ]]; then
    todo "zsh : au premier lancement, l'assistant Powerlevel10k te fait choisir le style du prompt (relance-le avec p10k configure)."
  fi
  write_file "$HOME/.config/zsh/dotfiles.zsh" <<EOF
# zsh features from the dotfiles repo. Set one to 0 to turn it off, then run
# \`exec zsh\`. ./install.sh --disable <item> does the same.
DOTFILES_ZSH_LINE_KEYS=$(selected zsh-line-keys && echo 1 || echo 0)  # zsh-line-keys: Ctrl/Alt + Backspace/Delete, Alt + arrows
DOTFILES_ZSH_SELECTION=$(selected zsh-selection && echo 1 || echo 0)  # zsh-selection: Shift + arrows select, Alt+A/C/X
DOTFILES_ZSH_P10K=$(selected zsh-p10k && echo 1 || echo 0)  # zsh-p10k: Powerlevel10k prompt (0: Omarchy's starship)
DOTFILES_ZSH_PROGRESS=$(selected zsh-progress && echo 1 || echo 0)  # zsh-progress: cp/mv show total and per-file progress bars
EOF

  is_live || return 0

  if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]]; then
    if chsh -s /usr/bin/zsh; then
      todo "Déconnecte-toi puis reconnecte-toi : zsh sera ton shell dans les nouveaux terminaux."
    else
      warn "chsh a échoué, lance : chsh -s /usr/bin/zsh"
    fi
  fi

  if selected zsh-root && ! can_sudo; then
    todo "zsh pour root : relance ./install.sh dans un terminal (il demande le mot de passe sudo)."
  elif selected zsh-root; then
    # A copy, not a link: a link would let anything running as you change
    # what runs the next time a root shell opens.
    [[ $(getent passwd root | cut -d: -f7) == */zsh ]] || sudo chsh -s /usr/bin/zsh root
    sudo install -m 644 -o root -g root "$HOME/.zshrc" /root/
    [[ -f $HOME/.p10k.zsh ]] && sudo install -m 644 -o root -g root "$HOME/.p10k.zsh" /root/
    sudo install -D -m 644 -o root -g root "$HOME/.config/zsh/dotfiles.zsh" /root/.config/zsh/dotfiles.zsh
    ok "root : zsh avec la même config"
  fi
}
