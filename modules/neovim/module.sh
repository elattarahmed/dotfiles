# Neovim spell check in French and English (LazyVim turns spell on for text,
# markdown and git commits, in English only: every French word got a red wave),
# and LazyVim's neo-tree file explorer extra.
# Items: neovim-spell, neovim-neotree

module_neovim() {
  selected neovim-spell || selected neovim-neotree || return 0
  info "Neovim"

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
