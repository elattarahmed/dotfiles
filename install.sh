#!/bin/bash
# Puts this machine's Omarchy customizations on another Omarchy machine.
# Run ./install.sh --help for the options, and see README.md.

set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$DOTFILES_DIR/lib/common.sh"

# id|on or off by default|menu label (no commas: gum splits its selection on them)
ITEMS=(
  "theme|on|Thème Black_arch (et Hermarchy installé) avec un fond d'écran en plus"
  "browser-brave|on|Brave navigateur par défaut · les liens s'ouvrent dans le Brave déjà ouvert"
  "zsh|on|zsh par défaut · suggestions et coloration syntaxique"
  "zsh-p10k|on|zsh · prompt Powerlevel10k (son assistant fait choisir le style · sinon starship d'Omarchy)"
  "zsh-p10k-style|off|zsh · le style de prompt Powerlevel10k du dépôt tel quel (demande une police avec icônes Nerd Font)"
  "zsh-line-keys|on|zsh · Ctrl/Alt + Effacer/Suppr et Alt + flèches (début/fin de ligne)"
  "zsh-selection|on|zsh · sélection avec Maj + flèches · Alt+A/C/X tout sélectionner/copier/couper"
  "zsh-root|off|zsh et la même config pour root (sudo)"
  "ghostty|on|Ghostty comme terminal par défaut"
  "ghostty-font|on|Ghostty · texte en taille 11 au lieu de 9"
  "ghostty-tabs|on|Ghostty · Alt+T nouvel onglet · Alt+W fermer l'onglet"
  "resize-mode|on|Super+R puis flèches · redimensionner la fenêtre au clavier · indicateur RESIZE dans la barre"
  "workspace-keys|on|Super+Ctrl+←/→ · workspace précédent/suivant"
  "macos-keys|on|Alt comme Cmd sur Mac · Alt+C/V/X · Alt+A/Z/S/F/T/W/L/R · Alt+1…9 · Super+Q · Ctrl+Alt+Espace émojis"
  "natural-scroll|on|Pavé tactile · défilement naturel (comme sur Mac) et plus lent"
  "touchscreen-off|on|Écran tactile désactivé"
  "caps-lock|on|Verr. Maj en vrai Verr. Maj (É È Ç À Ù) · Compose sur Ctrl droit"
  "gestures|on|Glisser à 3 doigts ←/→ · changer de workspace"
  "zoom|on|Zoom façon macOS · clic à 3 doigts puis glisser ↑/↓ · remis à zéro pendant le verrouillage"
  "workspace-animation|on|Animation de glissement entre les workspaces"
  "no-middle-paste|on|Le clic du milieu (tap à 3 doigts) ne colle plus la sélection"
  "plymouth|on|Écran de démarrage (mot de passe du disque) aux couleurs Matte Black"
  "screensaver|on|Économiseur d'écran · ton texte en huit polices ASCII qui tournent (screensaver-text pour le changer)"
  "clipboard|on|Historique du presse-papiers avec épingles (Alt+Maj+V) et bouton dans la barre"
  "emojis|on|Sélecteur d'émojis · l'émoji sélectionné entouré d'une bordure claire"
  "scale-button|on|Barre · taille de l'affichage (molette ou clic pour agrandir/réduire)"
  "sysstats|on|Barre · RAM / CPU / température (clic pour passer de l'un à l'autre)"
  "whichport|off|Barre · whichport et les serveurs de dev qui tournent (compilé depuis GitHub)"
  "bar-layout|on|Barre · transparente · langue avant l'horloge et icônes d'applis après le réseau"
  "no-fcitx|on|Sans fcitx5 · Maj+flèches et touches mortes (^ ¨) fiables dans Ghostty"
  "lockscreen-layout|on|Écran de verrouillage dans la même disposition clavier que la session (utile seulement avec fcitx5)"
  "apps|on|Applications en terminal · tree · glow (Markdown) · pacseek (recherche de paquets)"
  "neovim-spell|on|Neovim · correcteur orthographique français + anglais"
  "neovim-themes|on|Neovim · choisir son thème à part de celui d'Omarchy (<leader>uC ou :Theme)"
  "neovim-neotree|on|Neovim · explorateur de fichiers neo-tree (extra LazyVim)"
  "rust|on|Rust · rustup stable avec clippy/rustfmt/rust-analyzer · Rustlings · LazyVim Rust"
  "git-ssh|on|Plusieurs comptes GitHub · une clé SSH et un alias github-<compte> chacun"
  "ssh-server|off|Serveur SSH · connexion depuis un autre ordinateur du réseau local seulement"
  "display-scale|off|Échelle de l'écran (demande la valeur)"
)

# Modules in the order they run. Each one reads `selected <id>` for its items.
MODULES=(theme browser zsh ghostty hyprland zoom-guard screensaver plymouth omarchy-plugins whichport input-method lockscreen-layout neovim rust apps git-ssh ssh-server display)

SELECTION_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/selection"
MODE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/mode"
TODOS=()
SELECTED=()
EXPLICIT=()

usage() {
  cat <<EOF
Usage: ./install.sh [options] [élément...]

Sans argument, un menu propose chaque élément (cochés : ceux déjà installés,
ou ceux par défaut la première fois).

  élément...        installe ces éléments en plus de ceux déjà choisis
  --disable élém... désactive ces éléments
  --all             installe tout
  --yes, -y         sans menu ni question (garde les choix enregistrés)
  --files-only      copie les fichiers seulement : pas de paquets, pas de sudo,
                    rien d'envoyé à la session en cours
  --link            met des liens vers le dépôt au lieu de copies : modifier
                    ces fichiers sur la machine modifie le dépôt (retenu)
  --copy            revient aux copies (retenu)
  --list            liste les éléments
  --help, -h        cette aide

Exemples :
  ./install.sh                     # menu
  ./install.sh --yes               # réinstalle les mêmes choix
  ./install.sh zoom                # ajoute le zoom
  ./install.sh --disable macos-keys
EOF
}

item_ids() {
  local item
  for item in "${ITEMS[@]}"; do echo "${item%%|*}"; done
}

is_item() { item_ids | grep -qxF -- "$1"; }

selected() { printf '%s\n' "${SELECTED[@]}" | grep -qxF -- "$1"; }
explicit() { printf '%s\n' "${EXPLICIT[@]}" | grep -qxF -- "$1"; }

saved_selection() {
  if [[ -f $SELECTION_FILE ]]; then
    grep -v '^\s*\(#\|$\)' "$SELECTION_FILE" || true
    return
  fi
  local item
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r id default _ <<<"$item"
    [[ $default == on ]] && echo "$id"
  done
  # The last item may be off: don't let its failed test become the return
  # value, or `set -e` drops the items given on the command line
  return 0
}

menu() {
  local preselect=() labels=() item id label
  local saved
  saved=$(saved_selection)
  for item in "${ITEMS[@]}"; do
    IFS='|' read -r id _ label <<<"$item"
    labels+=("$label|$id")
    grep -qxF -- "$id" <<<"$saved" && preselect+=("$label")
  done

  if command -v gum >/dev/null; then
    local joined
    joined=$(IFS=,; echo "${preselect[*]}")
    gum choose --no-limit --height 24 --label-delimiter="|" --selected="$joined" \
      --header "Espace pour cocher/décocher, Entrée pour valider" "${labels[@]}"
  else
    for item in "${ITEMS[@]}"; do
      IFS='|' read -r id _ label <<<"$item"
      local default=no
      grep -qxF -- "$id" <<<"$saved" && default=yes
      confirm "$label ?" "$default" && echo "$id"
    done
  fi
}

mode=install
args=()
all=0
link_choice=""
while (($#)); do
  case "$1" in
    --all) all=1 ;;
    --yes | -y) ASSUME_YES=1 ;;
    --files-only) FILES_ONLY=1 ;;
    --link) LINK=1; link_choice=link ;;
    --copy) LINK=0; link_choice=copy ;;
    --disable) mode=disable ;;
    --list)
      for item in "${ITEMS[@]}"; do
        IFS='|' read -r id default label <<<"$item"
        printf '%-20s %-4s %s\n' "$id" "$default" "$label"
      done
      exit 0
      ;;
    -h | --help) usage; exit 0 ;;
    -*) echo "Option inconnue : $1" >&2; usage >&2; exit 1 ;;
    *)
      is_item "$1" || { echo "Élément inconnu : $1 (voir ./install.sh --list)" >&2; exit 1; }
      args+=("$1")
      ;;
  esac
  shift
done

if ! command -v omarchy >/dev/null || ! command -v hyprctl >/dev/null; then
  warn "Omarchy n'a pas été trouvé : ces dotfiles sont faits pour Omarchy (Arch + Hyprland)."
  ((FILES_ONLY)) || confirm "Continuer quand même ?" no || exit 1
fi

# Links or copies: the last choice made with --link/--copy, copies otherwise
if [[ -z $link_choice && $(cat "$MODE_FILE" 2>/dev/null) == link ]]; then
  LINK=1
fi

if [[ $mode == disable ]]; then
  ((${#args[@]})) || { echo "--disable attend au moins un élément" >&2; exit 1; }
  mapfile -t SELECTED < <(saved_selection | grep -vxF -f <(printf '%s\n' "${args[@]}") || true)
elif ((${#args[@]})); then
  EXPLICIT=("${args[@]}")
  mapfile -t SELECTED < <({ saved_selection; printf '%s\n' "${args[@]}"; } | awk '!seen[$0]++')
elif ((all)); then
  mapfile -t SELECTED < <(item_ids)
elif interactive; then
  mapfile -t SELECTED < <(menu)
  ((${#SELECTED[@]})) || { echo "Rien de coché, rien à faire."; exit 0; }
else
  mapfile -t SELECTED < <(saved_selection)
fi

for module in "${MODULES[@]}"; do
  source "$DOTFILES_DIR/modules/$module/module.sh"
done
for module in "${MODULES[@]}"; do
  "module_${module//-/_}"
done

mkdir -p "$(dirname "$SELECTION_FILE")"
[[ -n $link_choice ]] && echo "$link_choice" >"$MODE_FILE"
{
  echo "# Éléments installés par $(pretty "$DOTFILES_DIR")/install.sh (un par ligne)"
  printf '%s\n' "${SELECTED[@]}"
} >"$SELECTION_FILE"

if is_live && command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload >/dev/null
  sleep 1
  errors=$(hyprctl configerrors 2>/dev/null | grep -v '^\s*$' || true)
  [[ -z $errors ]] || warn "Hyprland signale des erreurs de config :"$'\n'"$errors"
fi

info "Terminé"
if [[ -d $BACKUP_DIR ]]; then
  echo "  Anciennes versions des fichiers remplacés : $(pretty "$BACKUP_DIR")"
fi
if ((${#TODOS[@]})); then
  echo
  echo "À faire de ton côté :"
  printf '  • %s\n' "${TODOS[@]}"
fi
