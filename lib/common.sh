#!/usr/bin/env bash
# ============================================================================
# confepo / lib/common.sh
# Shared library sourced by install.sh and the `confepo` CLI.
# Pure functions + helpers — sourcing this file must have no side effects
# beyond defining variables/functions.
# ============================================================================

# ---------------------------------------------------------------------------
# Pretty logging
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'
  C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_DIM=$'\033[2m'
else
  C_RESET=; C_BLUE=; C_GREEN=; C_YELLOW=; C_RED=; C_DIM=
fi
info()  { printf '%s::%s %s\n'   "$C_BLUE"  "$C_RESET" "$*"; }
step()  { printf '\n%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_GREEN" "$*" "$C_RESET"; }
ok()    { printf '  %s✓%s %s\n'  "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '  %s!%s %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '%s✗ %s%s\n'    "$C_RED"   "$*" "$C_RESET" >&2; }
die()   { err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Repo location + privilege helper
# ---------------------------------------------------------------------------
# CONFEPO_DIR is the repo root. If a caller already exported it we trust it,
# otherwise we infer it from this file's location (lib/ -> repo root).
CONFEPO_DIR="${CONFEPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

ARCH="$(uname -m)"
STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"

# ---------------------------------------------------------------------------
# Distro / package-manager detection
# ---------------------------------------------------------------------------
detect_os() {
  CONFEPO_OS_ID="linux"
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    CONFEPO_OS_ID="${ID:-linux}"
  fi
  local family=" ${ID:-} ${ID_LIKE:-} "
  case "$family" in
    *arch*|*manjaro*|*endeavour*)            PKG=pacman ;;
    *debian*|*ubuntu*|*mint*|*pop*)          PKG=apt    ;;
    *fedora*|*rhel*|*centos*|*rocky*|*alma*) PKG=dnf    ;;
    *suse*)                                  PKG=zypper ;;
    *)
      local c
      for c in apt-get dnf pacman zypper; do
        if command -v "$c" >/dev/null 2>&1; then
          case "$c" in apt-get) PKG=apt ;; *) PKG="$c" ;; esac
          break
        fi
      done
      ;;
  esac
  [ -n "${PKG:-}" ] || die "No supported package manager found (apt/dnf/pacman/zypper)."
}

# ---------------------------------------------------------------------------
# One logical package name -> the real per-distro package name.
# Only exceptions are listed; everything else is assumed identical.
# ---------------------------------------------------------------------------
pkg_name() {
  local n="$1"
  case "$PKG:$n" in
    apt:fd|dnf:fd)                                 echo fd-find ;;
    pacman:fd|zypper:fd)                           echo fd ;;

    apt:nm-applet)                                 echo network-manager-gnome ;;
    pacman:nm-applet)                              echo network-manager-applet ;;
    dnf:nm-applet|zypper:nm-applet)                echo network-manager-applet ;;

    # xrandr / xsetroot / xset (session + wallpaper fallback)
    apt:xkb-utils)                                 echo x11-xserver-utils ;;
    pacman:xkb-utils)                              echo xorg-xrandr ;;
    dnf:xkb-utils|zypper:xkb-utils)                echo xrandr ;;
    # setxkbmap (keyboard-layout toggle) — a SEPARATE package from the above
    apt:setxkbmap)                                 echo x11-xkb-utils ;;
    pacman:setxkbmap)                              echo xorg-setxkbmap ;;
    dnf:setxkbmap)                                 echo xorg-x11-xkb-utils ;;
    zypper:setxkbmap)                              echo setxkbmap ;;
    # ImageMagick (lock-screen blur) is capitalised on rpm distros
    dnf:imagemagick|zypper:imagemagick)            echo ImageMagick ;;

    apt:pulse-utils)                               echo pulseaudio-utils ;;
    pacman:pulse-utils)                            echo libpulse ;;
    dnf:pulse-utils|zypper:pulse-utils)            echo pulseaudio-utils ;;

    apt:libnotify-bin)                             echo libnotify-bin ;;
    pacman:libnotify-bin|dnf:libnotify-bin|zypper:libnotify-bin) echo libnotify ;;

    apt:font-awesome)                              echo fonts-font-awesome ;;
    pacman:font-awesome)                           echo ttf-font-awesome ;;
    dnf:font-awesome|zypper:font-awesome)          echo fontawesome-fonts ;;

    apt:noto-fonts)                                echo fonts-noto-core ;;
    pacman:noto-fonts)                             echo noto-fonts ;;
    dnf:noto-fonts|zypper:noto-fonts)              echo google-noto-sans-fonts ;;

    apt:noto-emoji)                                echo fonts-noto-color-emoji ;;
    pacman:noto-emoji)                             echo noto-fonts-emoji ;;
    dnf:noto-emoji|zypper:noto-emoji)              echo google-noto-emoji-color-fonts ;;

    apt:dejavu-fonts)                              echo fonts-dejavu ;;
    pacman:dejavu-fonts)                           echo ttf-dejavu ;;
    dnf:dejavu-fonts|zypper:dejavu-fonts)          echo dejavu-sans-fonts ;;

    apt:firacode)                                  echo fonts-firacode ;;
    pacman:firacode)                               echo ttf-fira-code ;;
    dnf:firacode|zypper:firacode)                  echo fira-code-fonts ;;

    pacman:pipx)                                   echo python-pipx ;;

    *)                                             echo "$n" ;;
  esac
}

# Is a real package installed?
pkg_installed() {
  local p="$1"
  case "$PKG" in
    pacman) pacman -Qi  "$p" >/dev/null 2>&1 ;;
    apt)    dpkg -s     "$p" >/dev/null 2>&1 ;;
    dnf)    rpm -q      "$p" >/dev/null 2>&1 ;;
    zypper) rpm -q      "$p" >/dev/null 2>&1 ;;
    *)      return 2 ;;   # unknown PKG: "not installed" rather than a false yes
  esac
}

# Is a logical package available to install from the configured repos?
pkg_available() {
  local p; p="$(pkg_name "$1")"
  case "$PKG" in
    apt)
      local cand; cand="$(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/{print $2}')"
      [ -n "$cand" ] && [ "$cand" != "(none)" ] ;;
    pacman) pacman -Si "$p" >/dev/null 2>&1 ;;
    dnf)    dnf -q list "$p" >/dev/null 2>&1 ;;
    zypper) zypper -q info "$p" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

_pkg_refreshed=0
pkg_refresh() {
  [ "$_pkg_refreshed" = 1 ] && return 0
  case "$PKG" in
    apt)    $SUDO apt-get update -qq ;;
    pacman) $SUDO pacman -Sy --noconfirm >/dev/null ;;
    zypper) $SUDO zypper --non-interactive refresh >/dev/null ;;
    dnf)    : ;;  # dnf refreshes metadata on demand
  esac
  _pkg_refreshed=1
}

_pkg_raw_install() {  # args: real package names
  case "$PKG" in
    apt)    $SUDO apt-get install -y "$@" ;;
    dnf)    $SUDO dnf install -y "$@" ;;
    pacman) $SUDO pacman -S --needed --noconfirm "$@" ;;
    zypper) $SUDO zypper --non-interactive install "$@" ;;
  esac
}

# Install logical packages, skipping ones already present. Falls back to
# installing one-by-one so a single missing package can't abort the batch.
pkg_install() {
  local logical real missing=()
  for logical in "$@"; do
    real="$(pkg_name "$logical")"
    [ -z "$real" ] && continue
    if pkg_installed "$real"; then
      ok "$logical already present"
    else
      missing+=("$real")
    fi
  done
  [ ${#missing[@]} -eq 0 ] && return 0
  pkg_refresh
  info "Installing: ${missing[*]}"
  if _pkg_raw_install "${missing[@]}"; then
    return 0
  fi
  warn "Batch install hit an error; retrying individually…"
  local p
  for p in "${missing[@]}"; do
    _pkg_raw_install "$p" || warn "could not install '$p' (skipped)"
  done
}

# Install every logical package listed in a manifest file (# comments, blanks ok)
install_list() {
  local file="$1"
  [ -r "$file" ] || { warn "package list not found: $file"; return; }
  local line pkgs=()
  while IFS= read -r line; do
    line="${line%%#*}"
    # trim surrounding whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] && pkgs+=("$line")
  done < "$file"
  # NB: explicit `if` (not `&&`) so an empty manifest returns 0, not 1 — a bare
  # `[ … ] && …` would make this function fail under `set -e` at the call site.
  if [ ${#pkgs[@]} -gt 0 ]; then pkg_install "${pkgs[@]}"; fi
  return 0
}

# ---------------------------------------------------------------------------
# Tools that aren't reliably packaged everywhere
# ---------------------------------------------------------------------------

# Download a prebuilt release binary from GitHub into ~/.local/bin.
install_github_binary() {  # name repo asset binname
  local name="$1" repo="$2" asset="$3" binname="$4"
  local url="https://github.com/$repo/releases/latest/download/$asset"
  local tmp; tmp="$(mktemp -d)"
  info "Fetching $name binary from $repo"
  if curl -fsSL "$url" -o "$tmp/dl"; then
    case "$asset" in
      *.tar.gz|*.tgz) tar -xzf "$tmp/dl" -C "$tmp" ;;
      *.zip)          unzip -q "$tmp/dl" -d "$tmp" ;;
    esac
    local found; found="$(find "$tmp" -type f -name "$binname" 2>/dev/null | head -n1)"
    if [ -n "$found" ]; then
      install -Dm755 "$found" "$HOME/.local/bin/$binname"
      ok "$name -> ~/.local/bin/$binname"
    else
      warn "binary '$binname' not found in $name archive"
    fi
  else
    warn "download failed for $name ($url)"
  fi
  rm -rf "$tmp"
}

install_eza() {
  command -v eza >/dev/null 2>&1 && { ok "eza already present"; return; }
  if pkg_available eza; then pkg_install eza; fi
  command -v eza >/dev/null 2>&1 && return
  case "$ARCH" in
    x86_64)  install_github_binary eza eza-community/eza "eza_x86_64-unknown-linux-gnu.tar.gz"  eza ;;
    aarch64) install_github_binary eza eza-community/eza "eza_aarch64-unknown-linux-gnu.tar.gz" eza ;;
    *)       warn "no eza fallback binary for arch $ARCH" ;;
  esac
}

install_starship() {
  command -v starship >/dev/null 2>&1 && { ok "starship already present"; return; }
  if pkg_available starship; then pkg_install starship; fi
  command -v starship >/dev/null 2>&1 && return
  info "Installing starship via official installer -> ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install/install.sh | sh -s -- -y -b "$HOME/.local/bin" \
    || warn "starship install failed (prompt will fall back to default)"
}

install_autotiling() {
  command -v autotiling >/dev/null 2>&1 && { ok "autotiling already present"; return; }
  if command -v pipx >/dev/null 2>&1; then
    pipx install autotiling >/dev/null 2>&1 && ok "autotiling via pipx" \
      || warn "autotiling install failed"
    pipx ensurepath >/dev/null 2>&1 || true
  else
    warn "pipx missing — skipping autotiling"
  fi
}

# Optional Nerd Font so prompt/eza icons render. Best-effort.
install_nerd_font() {
  if fc-list 2>/dev/null | grep -qi "FiraCode Nerd"; then ok "Nerd Font present"; return; fi
  local dest="$HOME/.local/share/fonts"
  mkdir -p "$dest"
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip" \
        -o "$tmp/f.zip" && unzip -qo "$tmp/f.zip" -d "$dest" '*.ttf' 2>/dev/null; then
    fc-cache -f "$dest" >/dev/null 2>&1 || true
    ok "FiraCode Nerd Font installed"
  else
    warn "Nerd Font download failed (terminal/prompt icons may be missing)"
  fi
  rm -rf "$tmp"
}

# On Debian/Ubuntu the binaries are batcat / fdfind — add bat / fd shims.
make_shims() {
  mkdir -p "$HOME/.local/bin"
  if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; ok "shim bat -> batcat"
  fi
  if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; ok "shim fd -> fdfind"
  fi
}

# ---------------------------------------------------------------------------
# Dotfile symlinking (GNU Stow)
# ---------------------------------------------------------------------------

# Real directories we want to exist before stowing, so that:
#  - apps that write into their config dir (fish/fisher) don't pollute the repo
#  - multiple stow packages can share ~/.config without tree-folding clashes
ensure_dirs() {
  mkdir -p \
    "$HOME/.config" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/fonts" \
    "$HOME/.cache" \
    "$HOME/.config/git" \
    "$HOME/.config/fish/conf.d" \
    "$HOME/.config/fish/functions" \
    "$HOME/.config/fish/completions" \
    "$HOME/.claude/agents" \
    "$HOME/.claude/skills" \
    "$HOME/.claude/commands"
}

# Make sure our scripts are executable at the source (symlinks inherit the bit).
fix_perms() {
  chmod +x "$CONFEPO_DIR"/install.sh "$CONFEPO_DIR"/uninstall.sh "$CONFEPO_DIR"/lib/*.sh 2>/dev/null || true
  chmod +x "$CONFEPO_DIR"/stow/bin/.local/bin/* 2>/dev/null || true
  chmod +x "$CONFEPO_DIR"/stow/i3blocks/.config/i3blocks/scripts/* 2>/dev/null || true
}

# Back up any pre-existing real file that a stow package would overwrite.
backup_conflicts() {
  local bdir="$HOME/.confepo-backup/$STAMP"
  local pkgdir rel target real f
  for pkgdir in "$CONFEPO_DIR"/stow/*/; do
    while IFS= read -r f; do
      rel="${f#"$pkgdir"}"
      target="$HOME/$rel"
      [ -e "$target" ] || continue
      [ -L "$target" ] && continue            # already a symlink we manage
      # Safety net: never touch a path that already resolves INTO our repo
      # (e.g. reached through a stow-folded directory symlink) — moving it
      # would delete our own source file.
      real="$(readlink -f "$target" 2>/dev/null || true)"
      case "$real" in "$CONFEPO_DIR"/*) continue ;; esac
      mkdir -p "$bdir/$(dirname "$rel")"
      mv "$target" "$bdir/$rel" && warn "backed up $target -> $bdir/$rel"
    done < <(find "$pkgdir" -type f)
  done
}

# Symlink every stow package into $HOME (idempotent via --restow).
link_dotfiles() {
  command -v stow >/dev/null 2>&1 || pkg_install stow
  fix_perms
  ensure_dirs
  backup_conflicts
  # --no-folding: always create per-file symlinks inside real directories,
  # never fold a whole directory into a single symlink. This keeps app-written
  # runtime files out of the repo and prevents re-runs from traversing a folded
  # symlink back into our own source tree.
  local pkg name
  for pkg in "$CONFEPO_DIR"/stow/*/; do
    name="$(basename "$pkg")"
    if stow --restow --no-folding --target="$HOME" --dir="$CONFEPO_DIR/stow" "$name" 2>/dev/null; then
      ok "linked $name"
    else
      warn "stow reported a conflict for '$name' (run: stow -nv $name)"
    fi
  done
}

# ---------------------------------------------------------------------------
# fish shell
# ---------------------------------------------------------------------------
setup_fish() {
  local fish_bin; fish_bin="$(command -v fish || true)"
  [ -n "$fish_bin" ] || { warn "fish not installed; skipping fish setup"; return; }

  # NOTE: /etc/shells registration lives in set_default_shell() — it's only
  # needed when we actually chsh, so --no-chsh stays fully hands-off (no sudo).

  # Install fisher (if absent) and sync plugins from the committed fish_plugins.
  if fish -c '
      if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        and fisher install jorgebucaran/fisher
      end
      fisher update' 2>/dev/null; then
    ok "fish plugins synced (fisher update)"
  else
    warn "fisher sync failed (check network); fish still works without plugins"
  fi
}

set_default_shell() {
  local fish_bin; fish_bin="$(command -v fish || true)"
  [ -n "$fish_bin" ] || return
  if [ "${SHELL:-}" = "$fish_bin" ]; then ok "fish is already the default shell"; return; fi
  # Register fish as a valid login shell first (chsh refuses otherwise).
  if ! grep -qxF "$fish_bin" /etc/shells 2>/dev/null; then
    echo "$fish_bin" | $SUDO tee -a /etc/shells >/dev/null && ok "registered $fish_bin in /etc/shells"
  fi
  if chsh -s "$fish_bin"; then
    ok "default shell set to fish (effective on next login)"
  else
    warn "chsh failed — run manually:  chsh -s $fish_bin"
  fi
}

# ---------------------------------------------------------------------------
# Doctor: report what's installed
# ---------------------------------------------------------------------------
confepo_doctor() {
  step "confepo doctor"
  printf '  %-14s %s\n' "repo:" "$CONFEPO_DIR"
  printf '  %-14s %s\n' "distro:" "${CONFEPO_OS_ID:-?} (pkg: ${PKG:-?})"
  local t
  for t in fish starship stow git nano tmux i3 i3blocks rofi picom dunst \
           eza bat fd rg fzf zoxide btop duf delta autotiling alacritty \
           setxkbmap pactl flameshot feh; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$t"
    else
      printf '  %s·%s %s %s(missing)%s\n' "$C_DIM" "$C_RESET" "$t" "$C_DIM" "$C_RESET"
    fi
  done
}

# ---------------------------------------------------------------------------
# Uninstall / revert
#   DRY_RUN=1     -> print actions, change nothing
#   NO_RESTORE=1  -> remove symlinks but don't restore backups
#   RESTORE_FROM  -> a specific ~/.confepo-backup/<stamp> to restore from
# ---------------------------------------------------------------------------

# True if $1 is a symlink that resolves into our repo (i.e. one we created).
_is_our_link() {
  [ -L "$1" ] || return 1
  case "$(readlink -f "$1" 2>/dev/null)" in "$CONFEPO_DIR"/*) return 0 ;; *) return 1 ;; esac
}

# Backup directories, oldest first (the oldest holds the true pre-confepo file).
_backup_dirs() {
  local d
  for d in "$HOME"/.confepo-backup/*/; do [ -d "$d" ] && printf '%s\n' "${d%/}"; done | sort
}

# Show what confepo currently has linked + which backups exist.
list_state() {
  local pkg rel target f any=0
  step "confepo-managed symlinks in \$HOME"
  for pkg in "$CONFEPO_DIR"/stow/*/; do
    while IFS= read -r f; do
      rel="${f#"$pkg"}"; target="$HOME/$rel"
      if _is_our_link "$target"; then printf '  %s\n' "${target/#$HOME/\~}"; any=1; fi
    done < <(find "$pkg" -type f)
  done
  [ $any = 0 ] && echo "  (none linked)"
  step "available backups in ~/.confepo-backup"
  local d n
  if [ -n "$(_backup_dirs)" ]; then
    while IFS= read -r d; do n=$(find "$d" -type f | wc -l); printf '  %s  (%s files)\n' "$(basename "$d")" "$n"; done < <(_backup_dirs)
  else
    echo "  (none)"
  fi
}

# Remove confepo's symlinks for one package, then prune emptied app dirs.
unlink_pkg() {
  local pkg="$1" rel target f d
  local pkgdir="$CONFEPO_DIR/stow/$pkg"
  [ -d "$pkgdir" ] || { warn "no such package: $pkg"; return 1; }
  while IFS= read -r f; do
    rel="${f#"$pkgdir"/}"; target="$HOME/$rel"
    _is_our_link "$target" || continue
    if [ "${DRY_RUN:-0}" = 1 ]; then echo "  would unlink ${target/#$HOME/\~}"
    else rm -f "$target" && ok "unlinked ${target/#$HOME/\~}"; fi
  done < <(find "$pkgdir" -type f)
  [ "${DRY_RUN:-0}" = 1 ] && return 0
  # prune app dirs that are now empty — never the shared XDG roots
  while IFS= read -r d; do
    rel="${d#"$pkgdir"/}"
    case "$rel" in
      .config|.local|.local/bin|.local/share|.local/share/fonts|.cache|\
      .config/fish|.config/fish/conf.d|.config/fish/functions|.config/fish/completions|.config/git) continue ;;
    esac
    rmdir "$HOME/$rel" 2>/dev/null || true
  done < <(find "$pkgdir" -mindepth 1 -type d | sort -r)
}

# Restore a package's original files from backup (oldest backup wins → the
# true pre-confepo file). Never clobbers a file you have in place now.
restore_pkg() {
  local pkg="$1" rel target src b f restored=0
  local pkgdir="$CONFEPO_DIR/stow/$pkg"
  local -a bdirs
  if [ -n "${RESTORE_FROM:-}" ]; then
    bdirs=("$HOME/.confepo-backup/$RESTORE_FROM")
    [ -d "${bdirs[0]}" ] || { warn "no such backup: $RESTORE_FROM"; return 1; }
  else
    mapfile -t bdirs < <(_backup_dirs)
  fi
  [ ${#bdirs[@]} -eq 0 ] && return 0
  while IFS= read -r f; do
    rel="${f#"$pkgdir"/}"; target="$HOME/$rel"
    # leave it if anything is already there — including a user's dangling symlink
    { [ -e "$target" ] || [ -L "$target" ]; } && continue
    for b in "${bdirs[@]}"; do
      src="$b/$rel"
      [ -e "$src" ] || continue
      if [ "${DRY_RUN:-0}" = 1 ]; then
        echo "  would restore ${target/#$HOME/\~}  (from $(basename "$b"))"
      else
        mkdir -p "$(dirname "$target")"
        mv "$src" "$target" && ok "restored ${target/#$HOME/\~}"
        restored=$((restored + 1))
      fi
      break
    done
  done < <(find "$pkgdir" -type f)
  return 0
}

# Unlink everything, then (unless NO_RESTORE) restore originals.
uninstall_all() {
  local pkg
  step "Unlinking confepo symlinks"
  for pkg in "$CONFEPO_DIR"/stow/*/; do unlink_pkg "$(basename "$pkg")"; done
  if [ "${NO_RESTORE:-0}" != 1 ]; then
    step "Restoring original files from backup"
    for pkg in "$CONFEPO_DIR"/stow/*/; do restore_pkg "$(basename "$pkg")"; done
  fi
}

# Reset the login shell back to bash.
revert_shell() {
  local sh; sh="$(command -v bash || echo /bin/bash)"
  if [ "${DRY_RUN:-0}" = 1 ]; then echo "  would run: chsh -s $sh"; return 0; fi
  if [ "${SHELL:-}" = "$sh" ]; then ok "login shell already $sh"; return 0; fi
  if chsh -s "$sh"; then ok "login shell reset to bash (re-login to apply)"
  else warn "chsh failed — run manually:  chsh -s $sh"; fi
}

# Remove confepo's own state files (not your packages, not your edited configs).
purge_state() {
  local d="$HOME/.config/confepo" gl="$HOME/.config/git/config.local"
  if [ -e "$d" ]; then
    if [ "${DRY_RUN:-0}" = 1 ]; then echo "  would remove ~/.config/confepo"
    else rm -rf "$d" && ok "removed ~/.config/confepo"; fi
  fi
  # only remove the git identity stub if it's still the untouched template
  if [ -f "$gl" ]; then
    if grep -qE '^[[:space:]]*[^#[:space:]].*=' "$gl"; then
      info "kept ~/.config/git/config.local (you edited it)"
    elif [ "${DRY_RUN:-0}" = 1 ]; then echo "  would remove unmodified ~/.config/git/config.local"
    else rm -f "$gl" && ok "removed unmodified ~/.config/git/config.local"; fi
  fi
}
