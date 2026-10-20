# Neovim spell check in French and English. LazyVim turns spell on for text,
# markdown and git commits, in English only: every French word got a red wave.
# Item: neovim-spell

module_neovim() {
  selected neovim-spell || return 0
  info "Neovim"

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
