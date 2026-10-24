# Shared helpers for install.sh and the modules. Sourced, not run.

DOTFILES_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
BACKUP_DIR="$DOTFILES_STATE/backups/$(date +%Y%m%d-%H%M%S)"

# FILES_ONLY=1 writes files and nothing else: no packages, no sudo, no talking
# to the running Hyprland/Omarchy session. Used for tests and dry runs.
FILES_ONLY=${FILES_ONLY:-0}
ASSUME_YES=${ASSUME_YES:-0}
# LINK=1 puts links to the repo's files instead of copies (install.sh --link),
# so editing them on the machine edits the repo. Systemd units and files the
# modules generate stay copies.
LINK=${LINK:-0}

info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
todo() { TODOS+=("$*"); }

is_live() { ((!FILES_ONLY)); }
# sudo can only ask for a password (or a fingerprint) in a terminal
can_sudo() { [[ -t 0 ]]; }
interactive() { ((!ASSUME_YES)) && [[ -t 0 ]]; }
pretty() { printf '%s' "${1/#$HOME/\~}"; }

# ask "Question" default -> answer on stdout (default when not interactive)
ask() {
  local question=$1 default=${2:-} answer
  if ! interactive; then
    printf '%s' "$default"
    return
  fi
  if command -v gum >/dev/null; then
    # An explicit placeholder: gum 2.0 fails on an empty --value without one
    answer=$(gum input --placeholder "" --prompt "$question " --value "$default") || answer=$default
  else
    read -r -p "$question [$default] " answer </dev/tty || true
    answer=${answer:-$default}
  fi
  printf '%s' "$answer"
}

# confirm "Question" [default yes|no]
confirm() {
  local question=$1 default=${2:-yes}
  if ! interactive; then
    [[ $default == yes ]]
    return
  fi
  if command -v gum >/dev/null; then
    if [[ $default == yes ]]; then gum confirm "$question"; else gum confirm --default=false "$question"; fi
  else
    local answer
    read -r -p "$question [$([[ $default == yes ]] && echo O/n || echo o/N)] " answer </dev/tty || true
    answer=${answer:-$([[ $default == yes ]] && echo o || echo n)}
    [[ $answer =~ ^[oOyY] ]]
  fi
}

# Copy what a file or directory currently holds into this run's backup folder.
backup() {
  local target=$1
  [[ -e $target || -L $target ]] || return 0
  local dest="$BACKUP_DIR/${target#"$HOME"/}"
  mkdir -p "$(dirname "$dest")"
  cp -a "$target" "$dest"
}

# Whether SRC should be linked rather than copied
links_to_repo() {
  local src=$1 dest=$2
  ((LINK)) && [[ $src == "$DOTFILES_DIR"/* && $dest != *.service ]]
}

# link SRC DEST: DEST becomes a link to SRC, backing up what it replaces.
link() {
  local src=$1 dest=$2
  [[ -L $dest && $(readlink "$dest") == "$src" ]] && return 0
  backup "$dest"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  ok "$(pretty "$dest") → dépôt"
}

# install_file SRC DEST [MODE]: copy (or link, see LINK) unless already
# identical, backing up the old file.
install_file() {
  local src=$1 dest=$2 mode=${3:-644}
  if links_to_repo "$src" "$dest"; then
    link "$src" "$dest"
    return
  fi
  if [[ -f $dest && ! -L $dest ]] && cmp -s "$src" "$dest"; then
    return 0
  fi
  backup "$dest"
  rm -f "$dest"
  install -Dm"$mode" "$src" "$dest"
  ok "$(pretty "$dest")"
}

# install_dir SRC DEST: replace DEST with a copy (or link) of SRC unless
# already identical.
install_dir() {
  local src=$1 dest=$2
  if links_to_repo "$src" "$dest"; then
    link "$src" "$dest"
    return
  fi
  if [[ -d $dest && ! -L $dest ]] && diff -rq "$src" "$dest" >/dev/null 2>&1; then
    return 0
  fi
  backup "$dest"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -r "$src" "$dest"
  ok "$(pretty "$dest")/"
}

# write_file DEST <<EOF ... : like install_file, with the content on stdin.
write_file() {
  local dest=$1 tmp
  tmp=$(mktemp)
  cat >"$tmp"
  install_file "$tmp" "$dest"
  rm -f "$tmp"
}

# ensure_block FILE MARKER TEXT: append TEXT once; MARKER is a line that identifies it.
ensure_block() {
  local file=$1 marker=$2 text=$3
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -qF -- "$marker" "$file"; then
    return 0
  fi
  backup "$file"
  printf '\n%s\n' "$text" >>"$file"
  ok "$(pretty "$file")"
}

# Packages, through Omarchy's helpers (they ask for the sudo password).
pkg_add() {
  is_live || return 0
  omarchy pkg missing "$@" || return 0
  if ! can_sudo; then
    todo "Paquets à installer : $* (relance ./install.sh dans un terminal)"
    return 0
  fi
  info "Paquets : $*"
  omarchy pkg add "$@"
}

aur_add() {
  is_live || return 0
  omarchy pkg missing "$@" || return 0
  if ! can_sudo; then
    todo "Paquets AUR à installer : $* (relance ./install.sh dans un terminal)"
    return 0
  fi
  info "Paquets AUR : $*"
  omarchy pkg aur add "$@"
}

# enable_plugin ID [placement...]: make the shell see a plugin copied into
# ~/.config/omarchy/plugins, then enable it (bar widgets land at the placement).
enable_plugin() {
  local id=$1
  shift
  is_live || return 0
  command -v omarchy-shell >/dev/null || return 0

  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  local attempt
  for ((attempt = 0; attempt < 60; attempt++)); do
    omarchy plugin list --json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id)' >/dev/null && break
    sleep 0.1
  done

  if omarchy plugin list --json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id and .enabled)' >/dev/null; then
    return 0
  fi
  if omarchy plugin enable "$id" "$@" >/dev/null; then
    ok "plugin $id activé"
  else
    warn "impossible d'activer le plugin $id (omarchy plugin enable $id)"
  fi
}

disable_plugin() {
  is_live || return 0
  omarchy plugin list --json 2>/dev/null | jq -e --arg id "$1" 'any(.[]; .id == $id and .enabled)' >/dev/null || return 0
  omarchy plugin disable "$1" >/dev/null && ok "plugin $1 désactivé"
}
