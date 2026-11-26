# Framework Laptop 13 (AMD Ryzen AI 300): the real built-in microphone as the
# default input. The firmware's AMD audio coprocessor card is a phantom (a
# flat, stuck signal, labelled "Digital Microphone"); with UCM off for the
# Realtek ALC285 card, its analog profile gives the internal microphone, put
# ahead of the empty headset jack and of Bluetooth headsets. The screen
# recorder (Super+Ctrl+C) records the default input, so it records this one,
# which the privacy switch cuts. Only installed on that exact model.
# Item: builtin-mic

BUILTIN_MIC_VOLUME=0.30   # above ~0.45 the Internal Mic Boost clips

builtin_mic_model() {
  [[ $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) == Framework &&
    $(cat /sys/class/dmi/id/product_name 2>/dev/null) == "Laptop 13 (AMD Ryzen AI 300 Series)" ]]
}

module_builtin_mic() {
  local src="$DOTFILES_DIR/modules/builtin-mic/51-dotfiles-framework13-mic.conf"
  local dest="$HOME/.config/wireplumber/wireplumber.conf.d/51-dotfiles-framework13-mic.conf"
  local changed=0

  if selected builtin-mic && builtin_mic_model; then
    info "Micro : le vrai micro intégré du Framework 13 par défaut"
    cmp -s "$src" "$dest" 2>/dev/null || changed=1
    install_file "$src" "$dest"
  elif [[ -f $dest ]]; then
    rm -f "$dest"
    ok "$(pretty "$dest") supprimé"
    changed=1
  else
    return 0
  fi

  is_live || return 0
  if ((changed)); then
    systemctl --user restart wireplumber && ok "WirePlumber redémarré"
    sleep 2
  fi
  selected builtin-mic || return 0

  local source volume
  source=$(pactl get-default-source 2>/dev/null)
  if [[ $source != alsa_input.pci-*analog-stereo ]]; then
    warn "micro par défaut : $source (attendu : l'entrée analogique du Framework)"
    return 0
  fi
  volume=$(wpctl get-volume @DEFAULT_SOURCE@ 2>/dev/null | awk '{print $2}')
  if awk -v v="${volume:-1}" 'BEGIN { exit !(v > 0.45) }'; then
    wpctl set-volume @DEFAULT_SOURCE@ "$BUILTIN_MIC_VOLUME" && ok "volume du micro à 30 % (il sature au-dessus de 45 %)"
  fi
  # 7.2.15-1 doesn't start the microphone (kernel quirk); later builds do
  local newer
  newer=$(command ls /usr/lib/modules 2>/dev/null | grep -E '^7\.2\.15-[2-9]' | grep -vx "$(uname -r)" | head -1)
  if [[ $(uname -r) == 7.2.15-1-* && -n $newer ]]; then
    todo "Micro intégré : redémarre l'ordinateur. Le noyau en cours ($(uname -r)) ne démarre pas le micro ; $newer, installé, devrait le faire (signalé corrigé à partir de 7.2.15-2)."
  fi
}
