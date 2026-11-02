# Omarchy theme. Omarchy's own commands switch everything at once (terminal,
# bar, lock screen, wallpaper…). Extra themes come from their git repos, plus
# the wallpapers added to them here (backgrounds/<theme>/).
# Items: theme, hyde-themes (themes from the HyDE gallery, converted by hyde-theme)

# Themes cloned from git, then the one in use and its wallpaper
THEME_REPOS=(
  https://github.com/ankur311sudo/black_arch.git
  https://github.com/archer-clawbot/omarchy-hermarchy-theme.git
)
THEME_NAME="black_arch"
THEME_BACKGROUND="14-dot-hands.jpg"

# HyDE gallery themes installed with hyde-themes (names as in `hyde-theme list`).
# Each is downloaded and converted on install; its wallpapers stay out of the repo.
HYDE_THEMES=()

module_theme() {
  if selected hyde-themes; then
    info "Thèmes HyDE"
    install_file "$DOTFILES_DIR/modules/theme/hyde-theme" "$HOME/.local/bin/hyde-theme" 755
    if is_live && ((${#HYDE_THEMES[@]})); then
      "$DOTFILES_DIR/modules/theme/hyde-theme" install --missing "${HYDE_THEMES[@]}" || warn "certains thèmes HyDE n'ont pas pu être installés"
    fi
  elif [[ -L $HOME/.local/bin/hyde-theme || -f $HOME/.local/bin/hyde-theme ]] && grep -q "HyDE gallery" "$HOME/.local/bin/hyde-theme" 2>/dev/null; then
    # The converted themes themselves are kept: they are ordinary themes now
    rm -f "$HOME/.local/bin/hyde-theme"
    ok "hyde-theme retiré"
  fi

  selected theme || return 0
  info "Thème"
  local themes="$HOME/.config/omarchy/themes"

  local url name
  for url in "${THEME_REPOS[@]}"; do
    # Same naming as omarchy-theme-install: repo name without omarchy-/-theme
    name=$(basename "$url" .git | sed -E 's/^omarchy-//; s/-theme$//' | tr '[:upper:]' '[:lower:]')
    if [[ ! -d $themes/$name ]] && is_live; then
      # Installing also switches to it; the theme in use is set below
      omarchy theme install "$url" >/dev/null 2>&1 && ok "thème $name installé" || warn "impossible d'installer le thème $name ($url)"
    fi
  done

  local dir="$DOTFILES_DIR/modules/theme/backgrounds" file
  for file in "$dir"/*/*; do
    [[ -f $file ]] || continue
    name=$(basename "$(dirname "$file")")
    [[ -d $themes/$name ]] || continue
    install_file "$file" "$themes/$name/backgrounds/$(basename "$file")"
  done

  is_live || return 0
  if [[ $(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null) == "$THEME_NAME" ]]; then
    ok "thème $THEME_NAME déjà actif"
  elif omarchy theme set "$THEME_NAME" >/dev/null 2>&1; then
    ok "thème $THEME_NAME"
  else
    warn "impossible d'appliquer le thème $THEME_NAME (omarchy theme list)"
    return 0
  fi

  local background="$HOME/.local/state/omarchy/current/theme/backgrounds/$THEME_BACKGROUND"
  if [[ -f $background && $(readlink -f "$HOME/.local/state/omarchy/current/background") != "$(readlink -f "$background")" ]]; then
    omarchy theme bg set "$background" >/dev/null 2>&1 && ok "fond d'écran $THEME_BACKGROUND"
  fi
}
