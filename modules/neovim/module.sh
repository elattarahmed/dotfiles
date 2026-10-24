# Neovim spell check in French and English (LazyVim turns spell on for text,
# markdown and git commits, in English only: every French word got a red wave),
# LazyVim's neo-tree file explorer extra, and a colorscheme picked on its own
# whatever the Omarchy theme (<leader>uC or :Theme).
# Items: neovim-spell, neovim-neotree, neovim-themes

module_neovim() {
  local choice="$HOME/.config/nvim/lua/plugins/theme-choice.lua"
  if ! selected neovim-themes && [[ -e $choice || -L $choice ]]; then
    backup "$choice"
    rm -f "$choice"
    ok "Neovim suit de nouveau le thème Omarchy"
  fi
  selected neovim-spell || selected neovim-neotree || selected neovim-themes || return 0
  info "Neovim"

  if selected neovim-themes; then
    if [[ -d $HOME/.config/nvim/lua/plugins ]]; then
      install_file "$DOTFILES_DIR/modules/neovim/theme-choice.lua" "$choice"
    else
      warn "pas de ~/.config/nvim/lua/plugins : sélecteur de thème ignoré"
    fi
  fi

  local lazyvim="$HOME/.config/nvim/lazyvim.json"
  if selected neovim-neotree; then
    if [[ -f $lazyvim ]]; then
      jq '.extras = ((.extras // []) + ["lazyvim.plugins.extras.editor.neo-tree"] | unique)' "$lazyvim" |
        write_file "$lazyvim"
    else
      warn "pas de ~/.config/nvim/lazyvim.json : active l'extra editor.neo-tree avec :LazyExtras"
    fi
  fi

  selected neovim-spell || return 0

  local options="$HOME/.config/nvim/lua/config/options.lua"
  if [[ -d $HOME/.config/nvim ]]; then
    ensure_block "$options" 'vim.opt.spelllang = { "fr", "en" }' '-- Spell check in French and English (LazyVim turns spell on for text,
-- markdown and git commits).
vim.opt.spelllang = { "fr", "en" }'
  else
    warn "pas de config Neovim dans ~/.config/nvim, réglage ignoré"
  fi

  # Neovim's own download prompt needs netrw, which LazyVim disables
  local spell="$HOME/.local/share/nvim/site/spell" file
  for file in fr.utf-8.spl fr.utf-8.sug; do
    [[ -s $spell/$file ]] && continue
    is_live || continue
    mkdir -p "$spell"
    if curl -fsSL -o "$spell/$file" "https://ftp.nluug.nl/pub/vim/runtime/spell/$file"; then
      ok "$(pretty "$spell/$file")"
    else
      rm -f "$spell/$file"
      warn "téléchargement de $file impossible"
    fi
  done
}
