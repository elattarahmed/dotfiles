# SSH server, to log in from another computer on the same network (a Mac, for
# instance). The firewall only lets in the local network, never the internet.
# Item: ssh-server (off by default: it opens the machine to remote logins)

# Local network of the main interface, e.g. 192.168.1.0/24
lan_subnet() {
  ip -4 -o route show scope link 2>/dev/null | awk '!/docker|br-|virbr|veth/ {print $1; exit}'
}

module_ssh_server() {
  selected ssh-server || return 0
  info "Serveur SSH"
  is_live || return 0

  pkg_add openssh
  if systemctl is-enabled --quiet sshd 2>/dev/null && systemctl is-active --quiet sshd; then
    ok "sshd déjà actif"
  elif ! can_sudo; then
    todo "Serveur SSH : relance ./install.sh dans un terminal (il demande le mot de passe sudo)."
    return 0
  elif sudo systemctl enable --now sshd >/dev/null 2>&1; then
    ok "sshd activé"
  else
    warn "impossible d'activer sshd (sudo systemctl enable --now sshd)"
  fi

  local subnet
  subnet=$(lan_subnet)
  if [[ -z $subnet ]]; then
    warn "réseau local introuvable : pare-feu non modifié"
  elif ! can_sudo; then
    todo "Serveur SSH : pare-feu non vérifié sans terminal (relance ./install.sh dans un terminal)."
  elif command -v ufw >/dev/null; then
    if sudo ufw allow from "$subnet" to any port 22 proto tcp comment 'SSH LAN' >/dev/null; then
      ok "pare-feu : SSH ouvert pour $subnet seulement"
    fi
  fi
  todo "SSH : depuis l'autre ordinateur, ssh $(whoami)@$(cat /etc/hostname 2>/dev/null || uname -n).local"
}
