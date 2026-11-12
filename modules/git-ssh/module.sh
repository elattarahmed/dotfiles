# Several GitHub accounts on one machine: one SSH key and one host alias per
# account, and git picks that account's name/email from the remote URL.
#   git clone git@github-<alias>:owner/repo.git
# A repo cloned that way keeps the account for good: its remote names the
# alias, and ~/.config/git/config includes the account's identity for every
# repo whose remote uses it (includeIf hasconfig:remote.*.url).
#
# Per account <alias> (typed as "hmd" or "github-hmd", the same account):
#   ~/.ssh/id_ed25519_github-<alias>     the key
#   ~/.ssh/config  Host github-<alias>   the alias
#   ~/.config/git/github-<alias>         name and email
#
# It runs first, so the questions come right after the menu.
# Item: git-ssh

GITCONFIG="$HOME/.config/git/config"
SSHCONFIG="$HOME/.ssh/config"

# "hmd", "github-hmd" or "github-github-hmd" -> "hmd"
git_alias() {
  local alias=$1
  while [[ $alias == github-* ]]; do alias=${alias#github-}; done
  printf '%s' "$alias"
}

# Accounts already set up, from the identity files
git_accounts() {
  local file
  for file in "$HOME"/.config/git/github-*; do
    [[ -f $file ]] && git config -f "$file" user.email >/dev/null && git_alias "$(basename "$file")" && echo
  done
}

# The remote URL forms that select the account: git@github-<a>:o/r,
# github-<a>:o/r (ssh config gives the user) and ssh://git@github-<a>/o/r
git_url_patterns() {
  printf '%s\n' "git@github-$1:*/**" "github-$1:*/**" "ssh://git@github-$1/**"
}

# The includeIf lines for one account, idempotent
git_link_identity() {
  local alias=$1 pattern
  while read -r pattern; do
    ensure_block "$GITCONFIG" "[includeIf \"hasconfig:remote.*.url:$pattern\"]" "[includeIf \"hasconfig:remote.*.url:$pattern\"]
	path = ~/.config/git/github-$alias"
  done < <(git_url_patterns "$alias")
}

# Before this fix, typing "github-hmd" as the alias made git wait for
# git@github-github-hmd: and never match a clone from git@github-hmd:
git_fix_doubled_alias() {
  local file
  for file in "$GITCONFIG" "$SSHCONFIG"; do
    grep -q 'github-github-' "$file" 2>/dev/null || continue
    backup "$file"
    sed -i -E 's/github-(github-)+/github-/g' "$file"
    ok "$(pretty "$file") : alias github-github-… corrigés en github-…"
  done
  # The first version kept identities in ~/.config/git/<alias>
  local base alias
  for file in "$HOME"/.config/git/*; do
    base=$(basename "$file")
    [[ -f $file && $base != github-* ]] || continue
    grep -qxF "	path = ~/.config/git/$base" "$GITCONFIG" 2>/dev/null || continue
    alias=$(git_alias "$base")
    [[ -e $HOME/.config/git/github-$alias ]] && continue
    backup "$GITCONFIG"
    mv "$file" "$HOME/.config/git/github-$alias"
    sed -i "s|^	path = ~/.config/git/$base\$|	path = ~/.config/git/github-$alias|" "$GITCONFIG"
    ok "identité $base → $(pretty "$HOME/.config/git/github-$alias")"
  done
}

git_add_account() {
  local alias name email key identity
  alias=$(git_alias "$(ask "Alias du compte (ex. perso, pro, hmd → github-hmd) :" "")")
  alias=${alias//[^A-Za-z0-9._-]/}
  if [[ -z $alias ]]; then
    warn "alias vide, compte ignoré"
    return 1
  fi
  identity="$HOME/.config/git/github-$alias"
  name=$(ask "[github-$alias] Nom affiché dans les commits :" "$(git config -f "$identity" user.name 2>/dev/null || true)")
  email=$(ask "[github-$alias] Email du compte GitHub :" "$(git config -f "$identity" user.email 2>/dev/null || true)")
  if [[ -z $name || -z $email ]]; then
    warn "[github-$alias] nom ou email vide, compte ignoré"
    return 1
  fi

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  key="$HOME/.ssh/id_ed25519_github-$alias"
  # Keys made by the first version of this module had no github- prefix
  [[ ! -f $key && -f $HOME/.ssh/id_ed25519_$alias ]] && key="$HOME/.ssh/id_ed25519_$alias"
  if [[ ! -f $key ]]; then
    echo "  Clé SSH pour github-$alias (une passphrase est recommandée) :"
    ssh-keygen -t ed25519 -C "$email" -f "$key"
  fi

  ensure_block "$SSHCONFIG" "Host github-$alias" "Host github-$alias
    HostName github.com
    User git
    IdentityFile ${key/#$HOME/\~}
    IdentitiesOnly yes"
  chmod 600 "$SSHCONFIG"

  write_file "$identity" <<EOF
[user]
	name = $name
	email = $email
EOF
  git_link_identity "$alias"

  echo
  echo "  Clé publique de github-$alias, à coller sur https://github.com/settings/ssh/new"
  echo "  (connecté au compte $email) :"
  echo
  sed 's/^/    /' "$key.pub"
  if command -v wl-copy >/dev/null && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    wl-copy <"$key.pub" && echo && echo "  (déjà copiée dans le presse-papiers)"
  fi
  echo
  todo "Clé de github-$alias : colle $(pretty "$key.pub") sur https://github.com/settings/ssh/new, puis teste avec ssh -T github-$alias"
}

module_git_ssh() {
  selected git-ssh || return 0
  info "Comptes GitHub (SSH)"

  # The GitHub CLI keeps its own login (a token, never stored in this repo)
  if is_live && command -v gh >/dev/null && ! gh auth status >/dev/null 2>&1; then
    todo "GitHub CLI : connecte-toi avec gh auth login."
  fi

  git_fix_doubled_alias
  local accounts alias
  mapfile -t accounts < <(git_accounts)
  # Older setups only had git@github-<a>:*/** ; add the other URL forms
  for alias in "${accounts[@]}"; do git_link_identity "$alias"; done
  # Repos that use no alias have no identity: git refuses to commit instead
  # of guessing one from the hostname.
  ensure_block "$GITCONFIG" "useConfigOnly = true" "[user]
	useConfigOnly = true"

  if ! interactive || ! is_live; then
    ((${#accounts[@]})) && ok "comptes : ${accounts[*]/#/github-}"
    ((${#accounts[@]})) || todo "Comptes GitHub : lance ./install.sh git-ssh dans un terminal, il pose quelques questions."
    return 0
  fi

  if ((${#accounts[@]})); then
    ok "comptes déjà configurés : ${accounts[*]/#/github-}"
    confirm "Ajouter un autre compte GitHub ?" no || return 0
  else
    echo "  Un compte GitHub = un alias (ex. github-perso, github-pro), une clé SSH et"
    echo "  le nom/email mis dans les commits des repos clonés avec cet alias."
  fi
  while true; do
    git_add_account || true
    confirm "Ajouter un autre compte GitHub ?" no || break
  done

  mapfile -t accounts < <(git_accounts)
  ((${#accounts[@]})) || return 0
  local first=${accounts[0]}
  todo "Cloner avec un compte : git clone git@github-$first:<owner>/<repo>.git — le repo garde ce compte pour ses commits (vérifie avec git config user.email)."
  todo "Repo déjà cloné avec github.com : git remote set-url origin git@github-$first:<owner>/<repo>.git"
}
