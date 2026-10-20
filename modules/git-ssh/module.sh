# Several GitHub accounts on one machine: one SSH key and one host alias per
# account, and git picks that account's name/email from the remote URL.
#   git clone git@github-<alias>:owner/repo.git
# Item: git-ssh

DEFAULT_GIT_ACCOUNTS="hmd oc"

module_git_ssh() {
  selected git-ssh || return 0
  info "Comptes GitHub (SSH)"

  local gitconfig="$HOME/.config/git/config" sshconfig="$HOME/.ssh/config"
  local configured
  configured=$(sed -n 's|^\[includeIf "hasconfig:remote\.\*\.url:git@github-\(.*\):\*/\*\*"\]$|\1|p' "$gitconfig" 2>/dev/null | xargs || true)
  if [[ -n $configured ]] && ! explicit git-ssh; then
    ok "déjà configuré : $configured (./install.sh git-ssh pour en ajouter)"
    return 0
  fi
  if ! interactive || ! is_live; then
    todo "Comptes GitHub : lance ./install.sh git-ssh dans un terminal, il pose quelques questions."
    return 0
  fi

  local known
  known=$(sed -n 's/^Host github-\(.*\)$/\1/p' "$sshconfig" 2>/dev/null | xargs || true)
  local accounts alias name email key identity
  accounts=$(ask "Alias des comptes, séparés par des espaces :" "${known:-$DEFAULT_GIT_ACCOUNTS}")

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  for alias in $accounts; do
    identity="$HOME/.config/git/$alias"
    name=$(ask "[$alias] Nom affiché dans les commits :" "$(git config -f "$identity" user.name 2>/dev/null || true)")
    email=$(ask "[$alias] Email du compte GitHub :" "$(git config -f "$identity" user.email 2>/dev/null || true)")
    if [[ -z $name || -z $email ]]; then
      warn "[$alias] nom ou email vide, compte ignoré"
      continue
    fi

    key="$HOME/.ssh/id_ed25519_$alias"
    if [[ ! -f $key ]]; then
      echo "  Clé SSH pour $alias (une passphrase est recommandée) :"
      ssh-keygen -t ed25519 -C "$email" -f "$key"
      todo "Ajoute la clé de « $alias » sur son compte GitHub (Settings → SSH and GPG keys) : cat $(pretty "$key.pub"), puis teste avec ssh -T github-$alias"
    fi

    ensure_block "$sshconfig" "Host github-$alias" "Host github-$alias
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_$alias
    IdentitiesOnly yes"
    chmod 600 "$sshconfig"

    write_file "$identity" <<EOF
[user]
	name = $name
	email = $email
EOF
    ensure_block "$gitconfig" "[includeIf \"hasconfig:remote.*.url:git@github-$alias:*/**\"]" "[includeIf \"hasconfig:remote.*.url:git@github-$alias:*/**\"]
	path = ~/.config/git/$alias"
  done

  # Repos that use neither alias have no identity: git refuses to commit
  # instead of guessing one from the hostname.
  ensure_block "$gitconfig" "useConfigOnly = true" "[user]
	useConfigOnly = true"
  todo "Pour un repo déjà cloné : git remote set-url origin git@github-<alias>:<owner>/<repo>.git"
}
