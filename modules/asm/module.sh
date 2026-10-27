# Assembleur x86-64 : la chaine NASM et les debogueurs pour la roadmap ESGI
# (meme esprit que le module rust). Le depot asm-roadmap lui-meme se cree avec
# le script init-asm-roadmap.sh du dossier ESGI, pas ici.
# Item: asm

module_asm() {
  selected asm || return 0
  info "Assembleur"

  # nasm: assembleur ; gdb + pwndbg: debogueur ; binutils: objdump/readelf/ld ;
  # strace/ltrace: appels systeme et de bibliotheque.
  pkg_add nasm gdb binutils strace ltrace pwndbg

  is_live || return 0
  command -v nasm >/dev/null && ok "$(nasm -v)"
}
