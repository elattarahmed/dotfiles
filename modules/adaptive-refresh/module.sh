# Adaptive refresh rate (VRR) for the Framework Laptop 13 AMD: the Hyprland
# side is hypr/dotfiles/adaptive_refresh.lua; this module adds the `hz` tool
# and the kernel parameter that makes VRR usable on that panel.
#
# amdgpu.dcdebugmask=0x610 turns Panel Self Refresh and Panel Replay off
# (0x10 PSR, 0x200 PSR-SU, 0x400 Replay). With them on, the panel leaves its
# self-refresh too slowly once VRR is enabled: the mouse and videos drop below
# 1 fps and the screen can freeze. It costs ~0.3-0.5 W on a still screen,
# which VRR wins back.
# Item: adaptive-refresh

VRR_CMDLINE_FILE=/etc/limine-entry-tool.d/amdgpu-vrr.conf
VRR_CMDLINE='KERNEL_CMDLINE[default]+=" amdgpu.dcdebugmask=0x610"'

vrr_cmdline_installed() {
  [[ -f $VRR_CMDLINE_FILE ]] && grep -qxF -- "$VRR_CMDLINE" "$VRR_CMDLINE_FILE"
}

module_adaptive_refresh() {
  local dir="$DOTFILES_DIR/modules/adaptive-refresh"
  local bin="$HOME/.local/bin/hz"

  if selected adaptive-refresh; then
    info "Hz adaptatifs (VRR)"
    install_file "$dir/hz" "$bin" 755
    is_live || return 0

    if [[ ! -d /sys/module/amdgpu ]]; then
      warn "pas de carte graphique AMD : le paramètre amdgpu n'est pas ajouté (le VRR peut quand même marcher)"
      return 0
    fi
    if vrr_cmdline_installed; then
      ok "paramètre noyau amdgpu.dcdebugmask=0x610 déjà en place"
    elif [[ ! -d $(dirname "$VRR_CMDLINE_FILE") ]] || ! command -v limine-update >/dev/null; then
      todo "Hz adaptatifs : ajoute amdgpu.dcdebugmask=0x610 aux paramètres du noyau (pas de Limine ici), puis redémarre."
    elif ! can_sudo; then
      todo "Hz adaptatifs : relance ./install.sh adaptive-refresh dans un terminal (il demande le mot de passe sudo)."
    else
      printf '%s\n' "$VRR_CMDLINE" | sudo tee "$VRR_CMDLINE_FILE" >/dev/null
      sudo limine-update >/dev/null
      ok "$VRR_CMDLINE_FILE (amdgpu.dcdebugmask=0x610)"
    fi
    if [[ $(cat /sys/module/amdgpu/parameters/dcdebugmask 2>/dev/null) != 1552 ]]; then
      todo "Hz adaptatifs : redémarre pour que le paramètre noyau s'applique. D'ici là, l'écran peut figer (Ctrl+Alt+F3 puis ./install.sh --disable adaptive-refresh pour revenir)."
    fi
  else
    if [[ -f $bin ]] && cmp -s "$dir/hz" "$bin"; then
      rm -f "$bin"
      ok "hz retiré"
    fi
    is_live || return 0
    vrr_cmdline_installed || return 0
    info "Hz adaptatifs (VRR)"
    if ! can_sudo; then
      todo "Hz adaptatifs à retirer : relance ./install.sh dans un terminal (il demande le mot de passe sudo)."
      return 0
    fi
    sudo rm -f "$VRR_CMDLINE_FILE"
    sudo limine-update >/dev/null
    ok "paramètre noyau amdgpu retiré (effectif au prochain démarrage)"
  fi
}
