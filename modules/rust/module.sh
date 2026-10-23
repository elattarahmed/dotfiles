# Rust: rustup's stable toolchain (through Omarchy's dev-env installer), the
# usual components (rust-analyzer, clippy, rustfmt, sources and docs), Rustlings, and LazyVim's Rust extra
# (rustaceanvim, crates.nvim and the codelldb debugger, fetched by Mason).
# Item: rust

RUST_LAZYVIM_EXTRA="lazyvim.plugins.extras.lang.rust"

module_rust() {
  selected rust || return 0
  info "Rust"

  local lazyvim="$HOME/.config/nvim/lazyvim.json"
  if [[ -f $lazyvim ]]; then
    jq --arg extra "$RUST_LAZYVIM_EXTRA" '.extras = ((.extras // []) + [$extra] | unique)' "$lazyvim" |
      write_file "$lazyvim"
  else
    warn "pas de ~/.config/nvim/lazyvim.json : active l'extra lang.rust avec :LazyExtras"
  fi

  is_live || return 0

  if [[ ! -x $HOME/.cargo/bin/rustup ]]; then
    omarchy install dev-env rust
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
  rustup component add rust-analyzer rust-src clippy rustfmt rust-docs
  ok "rustup $(rustc --version | cut -d' ' -f2)"

  if ! command -v rustlings >/dev/null; then
    cargo install --locked rustlings && ok "rustlings"
  fi
}
