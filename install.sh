#!/usr/bin/env bash
# ============================================================================
# confepo — install / bootstrap
#
#   ./install.sh                full setup (CLI tools + i3 desktop + dotfiles)
#   ./install.sh --no-desktop   shell + CLI tools only (skip i3/X stack)
#   ./install.sh --no-chsh      don't change the default login shell
#   ./install.sh --link-only    only (re)create the dotfile symlinks
#   ./install.sh --help
#
# Safe to re-run: every step is idempotent and pre-existing files are backed
# up to ~/.confepo-backup/<timestamp>/ before any symlink is created.
# ============================================================================
set -euo pipefail

CONFEPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONFEPO_DIR
# shellcheck source=lib/common.sh
. "$CONFEPO_DIR/lib/common.sh"

DESKTOP=1
SET_SHELL=1
LINK_ONLY=0

show_help() {
  cat <<'EOF'
confepo installer

  ./install.sh                full setup (CLI tools + i3 desktop + dotfiles)
  ./install.sh --no-desktop   shell + CLI tools only (skip i3/X stack)
  ./install.sh --no-chsh      don't change the default login shell
  ./install.sh --link-only    only (re)create the dotfile symlinks
  ./install.sh --help         show this help

Safe to re-run: idempotent; existing files are backed up to
~/.confepo-backup/<timestamp>/ before any symlink is created.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --no-desktop|--cli-only) DESKTOP=0 ;;
    --no-chsh)               SET_SHELL=0 ;;
    --link-only)             LINK_ONLY=1 ;;
    -h|--help)               show_help; exit 0 ;;
    *) die "unknown option: $arg (try --help)" ;;
  esac
done

detect_os
printf '\n'
info "Distro:          ${CONFEPO_OS_ID}"
info "Package manager: ${PKG}"
info "Architecture:    ${ARCH}"

# Heads-up if we can't elevate — package installs will be skipped, not silent.
if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
  warn "no root and no 'sudo' found — package installation will be SKIPPED."
  warn "dotfiles will still be linked; install packages yourself (see packages/)."
fi

# Remember where the repo lives so the `confepo` CLI can find it from anywhere.
mkdir -p "$HOME/.config/confepo"
printf '%s\n' "$CONFEPO_DIR" > "$HOME/.config/confepo/path"

if [ "$LINK_ONLY" = 1 ]; then
  step "Linking dotfiles only"
  link_dotfiles
  ok "done"
  exit 0
fi

step "Installing core CLI tools"
install_list "$CONFEPO_DIR/packages/common.txt"

step "Installing modern CLI extras"
install_eza
install_starship
make_shims
install_nerd_font

if [ "$DESKTOP" = 1 ]; then
  step "Installing i3 desktop environment"
  install_list "$CONFEPO_DIR/packages/desktop.txt"
  install_autotiling
else
  info "Skipping i3 desktop stack (--no-desktop)"
fi

step "Linking dotfiles"
link_dotfiles

# Non-tracked stub for personal git identity (so the symlinked git config can
# include it without us ever committing your name/email).
if [ ! -e "$HOME/.config/git/config.local" ]; then
  cat > "$HOME/.config/git/config.local" <<'EOF'
# Personal git identity — NOT tracked by confepo. Uncomment and fill in:
[user]
#	name = Your Name
#	email = you@example.com
EOF
  ok "created ~/.config/git/config.local (add your name/email there)"
fi

step "Configuring fish shell"
setup_fish
if [ "$SET_SHELL" = 1 ]; then
  set_default_shell
else
  info "Leaving default shell unchanged (--no-chsh)"
fi

step "All done 🎉"
cat <<EOF

  Next steps
  ----------
  • Log out and back in, then pick the "i3" session at the login screen.
  • A fresh fish shell now has abbreviations, fzf history (Ctrl-R) and the
    starship prompt. (If you didn't use --no-chsh, this is your default shell
    on next login; otherwise just run: fish)
  • Set a git identity in:        ~/.config/git/config.local
  • Set a wallpaper any time:     feh --bg-fill /path/to/image.jpg
  • Update everything later with: confepo update     (alias: up)
  • Health check:                 confepo doctor

  NOTE: the 'confepo' command lives in ~/.local/bin. If that's not on your
  PATH yet in THIS shell, open a new terminal (or log out/in) first, or run
  it by full path:  ~/.local/bin/confepo doctor

  In i3:  Super+Enter terminal · Super+D apps · Super+Space EN/HE toggle
          Super+Shift+S screenshot · Super+Esc lock · Super+Shift+E exit
  Backups of any replaced files are in: ~/.confepo-backup/${STAMP}/

EOF
