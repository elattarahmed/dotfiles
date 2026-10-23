# Terminal apps: tree (folder trees), glow (Markdown in the terminal) and
# pacseek (search and install packages, AUR included).
# Item: apps

module_apps() {
  selected apps || return 0
  info "Applications"
  pkg_add tree glow
  aur_add pacseek
}
