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

    # Docker engine — Debian/Ubuntu ship it as 'docker.io' (in-distro, no extra
    # apt repo or GPG key, keeps the install lightweight); elsewhere it's 'docker'.
    apt:docker)                                    echo docker.io ;;

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
    # xinput (touchpad toggle) — Arch splits it out of the server
    pacman:xinput)                                 echo xorg-xinput ;;
    # rfkill (airplane-mode key) — Arch folds it into util-linux
    pacman:rfkill)                                 echo util-linux ;;
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
# When the release publishes a "<asset>.sha256" sidecar we verify the download
# against it and refuse to install on mismatch. This is a same-origin integrity
# check — it catches corrupted/partial downloads and tampering that misses the
# sidecar, not a full GitHub compromise — but crucially it never executes a
# remote script (unlike a `curl | sh` installer), so a poisoned download cannot
# run arbitrary code: the worst case is a rejected or unused file in a tmpdir.
install_github_binary() {  # name repo asset binname
  local name="$1" repo="$2" asset="$3" binname="$4"
  local base="https://github.com/$repo/releases/latest/download"
  local tmp; tmp="$(mktemp -d)"
  info "Fetching $name binary from $repo"
  if ! curl -fsSL "$base/$asset" -o "$tmp/dl"; then
    warn "download failed for $name ($base/$asset)"; rm -rf "$tmp"; return
  fi
  if curl -fsSL "$base/$asset.sha256" -o "$tmp/sum" 2>/dev/null; then
    local want got
    want="$(grep -oiE '[0-9a-f]{64}' "$tmp/sum" | head -n1 | tr 'A-F' 'a-f')"
    got="$(sha256sum "$tmp/dl" | cut -d' ' -f1)"
    if [ -n "$want" ] && [ "$want" != "$got" ]; then
      warn "$name checksum MISMATCH — refusing to install (expected $want, got $got)"
      rm -rf "$tmp"; return
    fi
    [ -n "$want" ] && ok "$name checksum verified"
  else
    warn "$name: no published .sha256 sidecar — installing unverified"
  fi
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
  # Prebuilt binary from the official GitHub release rather than piping the
  # remote install script into a shell — no remote code execution, and
  # checksum-verified by install_github_binary when a .sha256 sidecar is present.
  info "Installing starship prebuilt binary -> ~/.local/bin"
  case "$ARCH" in
    x86_64)  install_github_binary starship starship/starship "starship-x86_64-unknown-linux-gnu.tar.gz"  starship ;;
    aarch64) install_github_binary starship starship/starship "starship-aarch64-unknown-linux-musl.tar.gz" starship ;;
    *)       warn "no starship prebuilt binary for arch $ARCH — install via your package manager" ;;
  esac
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
# Hardware-key permissions
#
# brightnessctl and the keyboard-backlight key write to sysfs files that the
# packaged udev rule chgrps to `video` (backlight) and `input` (LEDs) with
# group-write. Without membership the Fn brightness keys silently do nothing —
# which is the #1 "my function keys don't work under i3" gotcha. Add the user
# to both groups (idempotent). Takes effect on next login.
# ---------------------------------------------------------------------------
setup_input_groups() {
  local user; user="${SUDO_USER:-${USER:-}}"
  [ -n "$user" ] && [ "$user" != root ] || return 0

  # Which of the needed groups is the user NOT already a member of?
  local grp need=""
  for grp in video input; do
    getent group "$grp" >/dev/null 2>&1 || continue
    if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$grp"; then continue; fi
    need="${need:+$need }$grp"
  done
  if [ -z "$need" ]; then
    info "already in the video/input groups (brightness keys OK)"
    return 0
  fi

  # Membership changes need privilege — bail with a copy-paste hint if we lack it.
  if [ "$(id -u)" -ne 0 ] && [ -z "${SUDO:-}" ]; then
    warn "add yourself to the '$need' group(s) for the Fn brightness keys:"
    warn "    sudo usermod -aG video,input $user   (then log out and back in)"
    return 0
  fi

  local added="" failed=""
  for grp in $need; do
    if $SUDO usermod -aG "$grp" "$user"; then
      added="${added:+$added }$grp"
    else
      failed="${failed:+$failed }$grp"
    fi
  done
  if [ -n "$added" ]; then
    ok "added $user to: $added — log out/in for the brightness keys to take effect"
  fi
  if [ -n "$failed" ]; then
    warn "couldn't add $user to: $failed — run manually: sudo usermod -aG video,input $user"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Docker — installed but deliberately NOT running ("ready to use", not idling).
#
# We do not want a daemon burning RAM/at boot, so after install we disable both
# docker.service and its socket-activation unit: nothing runs until you say
# `sudo systemctl start docker` (and `stop` when done). We also add the user to
# the 'docker' group so the CLI needs no sudo once the daemon is up.
# Heads-up: docker-group membership is effectively root (a container can bind
# the host filesystem) — the standard convenience/security trade. Drop out of
# the group if you'd rather sudo each command. Group handling is idempotent;
# the daemon-disable is deliberately ONE-TIME (see the marker below).
# ---------------------------------------------------------------------------
setup_docker() {
  command -v docker >/dev/null 2>&1 || return 0   # package wasn't installed — nothing to do

  # 1) Keep the daemon dormant — ready, not running. Applied ONCE, recorded by
  #    a marker: the disable exists to undo the distro's install-time
  #    auto-enable, not to police the daemon forever. Without the marker every
  #    re-run/`confepo update` would stop the daemon — killing the running
  #    containers of anyone who deliberately enabled it.
  local marker="$HOME/.config/confepo/docker-dormant-applied"
  if [ -e "$marker" ]; then
    info "docker dormancy already applied once — daemon state is yours now"
  elif command -v systemctl >/dev/null 2>&1; then
    if [ "$(id -u)" -eq 0 ] || [ -n "${SUDO:-}" ]; then
      if $SUDO systemctl disable --now docker.service docker.socket >/dev/null 2>&1; then
        info "docker daemon left OFF — start on demand: sudo systemctl start docker"
        mkdir -p "${marker%/*}" && : > "$marker"
      fi
    else
      warn "keep the docker daemon off until needed:"
      warn "    sudo systemctl disable --now docker.service docker.socket"
    fi
  fi

  # 2) Group membership so `docker` needs no sudo (takes effect next login).
  local user; user="${SUDO_USER:-${USER:-}}"
  [ -n "$user" ] && [ "$user" != root ] || return 0
  getent group docker >/dev/null 2>&1 || return 0
  if id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    info "already in the 'docker' group"
    return 0
  fi
  if [ "$(id -u)" -ne 0 ] && [ -z "${SUDO:-}" ]; then
    warn "add yourself to the 'docker' group to run docker without sudo:"
    warn "    sudo usermod -aG docker $user   (then log out and back in)"
    return 0
  fi
  if $SUDO usermod -aG docker "$user"; then
    ok "added $user to the 'docker' group — log out/in for it to take effect"
  else
    warn "couldn't add $user to 'docker' — run manually: sudo usermod -aG docker $user"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# alacritty terminfo
#
# Our alacritty.toml sets TERM=alacritty for richer capabilities (styled
# underlines, true colour). That entry isn't in the base terminfo database and
# the apt package never registers it, so terminfo-using programs warn
# "unknown terminal type 'alacritty'" and fall back to xterm-256color. Compile
# the bundled source into ~/.terminfo — per-user, no sudo, works on any distro.
# ---------------------------------------------------------------------------
setup_alacritty_terminfo() {
  command -v alacritty >/dev/null 2>&1 || return 0
  if infocmp alacritty >/dev/null 2>&1; then
    info "alacritty terminfo already available"
    return 0
  fi
  if ! command -v tic >/dev/null 2>&1; then
    warn "tic not found (install ncurses) — alacritty terminfo not compiled"
    return 0
  fi
  local src="$CONFEPO_DIR/assets/terminfo/alacritty.info"
  [ -f "$src" ] || { warn "missing $src — cannot install alacritty terminfo"; return 0; }
  if tic -x -o "$HOME/.terminfo" "$src" >/dev/null 2>&1; then
    ok "compiled alacritty terminfo into ~/.terminfo (fixes TERM=alacritty warnings)"
  else
    warn "tic failed to compile $src — TERM=alacritty may still warn"
  fi
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
  # NOTE: puffer-fish is pinned to @v1.0.0 in fish_plugins on purpose — v1.1.0
  # calls `commandline --search-field` (fish >= 4.0 only), which errors on every
  # `.` keystroke under fish 3.x. Don't drop the pin without bumping fish first.
  # (Keep no comments IN fish_plugins: fisher rewrites that file and strips them.)
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
# Node.js via fnm (Fast Node Manager) — no sudo. Needed for the Playwright MCP
# and the Vite/React frontend POCs. Also activates Node in THIS process so the
# MCP registration below can see npx.
# ---------------------------------------------------------------------------
setup_node() {
  if command -v node >/dev/null 2>&1 && command -v npx >/dev/null 2>&1; then
    ok "node already present ($(node --version 2>/dev/null))"; return 0
  fi
  if ! command -v fnm >/dev/null 2>&1; then
    case "$ARCH" in
      x86_64)  install_github_binary fnm Schniz/fnm "fnm-linux.zip" fnm ;;
      aarch64) install_github_binary fnm Schniz/fnm "fnm-arm64.zip" fnm ;;
      *) warn "no fnm binary for arch $ARCH — install Node manually"; return 0 ;;
    esac
  fi
  command -v fnm >/dev/null 2>&1 || { warn "fnm unavailable — skipping Node"; return 0; }
  export PATH="$HOME/.local/bin:$PATH"
  # Install latest LTS, set default, and activate it in this shell so the rest
  # of install (e.g. the Playwright MCP) can use node/npx immediately.
  fnm install --lts >/dev/null 2>&1 || warn "fnm install --lts failed (network?)"
  eval "$(fnm env 2>/dev/null)" || true
  fnm use lts-latest >/dev/null 2>&1 || true
  fnm default lts-latest >/dev/null 2>&1 || true
  if command -v node >/dev/null 2>&1; then
    ok "Node $(node --version) ready via fnm"
  else
    warn "Node installed but not active in this shell — open a new fish session (fnm auto-loads)"
  fi
}

# ---------------------------------------------------------------------------
# Claude Code: register MCP servers (best-effort; needs Claude Code + Node/npx).
# The agents/skills + the active ~/.claude/CLAUDE.md are linked by stow; this
# wires up the Playwright browser MCP so the assistant can verify the UIs it builds.
# ---------------------------------------------------------------------------
# Install the Claude Code "attention" hooks into ~/.claude/settings.json. These
# feed the i3blocks `claude_status` block: a Notification (Claude wants input or
# a permission) flags the session; the next prompt / session end clears it. The
# merge is idempotent and preserves any hooks you already have.
setup_claude_hooks() {
  command -v claude >/dev/null 2>&1 || return 0
  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — skipping Claude attention hooks (install jq, then: confepo update)"
    return 0
  fi

  local settings="$HOME/.claude/settings.json"
  mkdir -p "$HOME/.claude"
  [ -f "$settings" ] || printf '{}\n' > "$settings"

  # Literal $HOME so the stored command stays portable; the hook shell expands it.
  local cmd='$HOME/.local/bin/confepo-claude-notify'
  local gate='$HOME/.local/bin/confepo-claude-blindgate'
  local tmp; tmp="$(mktemp)"

  # Split Notification by matcher so the chime only fires on a real permission
  # prompt, not on the idle "waiting for input" that follows every finished turn.
  # We also install a PreToolUse gate that keeps the `spec-tester` agent blind to
  # the implementation (it self-filters by agent_type, so it's a no-op for every
  # other agent and the main thread). We first STRIP any confepo-managed entries
  # (matched by helper name, migrating older layouts), then re-add the canonical
  # set — so this stays idempotent.
  if jq \
      --arg att  "$cmd attention" \
      --arg idle "$cmd idle" \
      --arg clr  "$cmd clear" \
      --arg gate "$gate" '
      def strip($e; $needle):
        .hooks[$e] = ((.hooks[$e] // [])
          | map(select(([.hooks[]?.command] | map(. // "")
                        | any(test($needle))) | not)));
      def add($e; $g): .hooks[$e] = ((.hooks[$e] // []) + [$g]);
      .hooks = (.hooks // {})
      | strip("Notification";     "confepo-claude-notify")
      | strip("UserPromptSubmit"; "confepo-claude-notify")
      | strip("SessionEnd";       "confepo-claude-notify")
      | strip("PreToolUse";       "confepo-claude-blindgate")
      | add("Notification"; {matcher: "permission_prompt", hooks: [ {type: "command", command: $att} ]})
      | add("Notification"; {matcher: "idle_prompt",       hooks: [ {type: "command", command: $idle} ]})
      | add("UserPromptSubmit"; {hooks: [ {type: "command", command: $clr} ]})
      | add("SessionEnd";       {hooks: [ {type: "command", command: $clr} ]})
      | add("PreToolUse"; {matcher: "Bash|Read|Grep|Glob|Write|Edit|MultiEdit|NotebookEdit", hooks: [ {type: "command", command: $gate} ]})
    ' "$settings" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    if cmp -s "$tmp" "$settings"; then
      rm -f "$tmp"
      info "Claude attention hooks already present"
    else
      cp "$settings" "$settings.confepo-bak" 2>/dev/null || true
      mv "$tmp" "$settings"
      ok "installed Claude attention hooks (chime on permission prompts only)"
    fi
  else
    rm -f "$tmp"
    warn "could not update $settings (invalid JSON?) — attention hooks not installed"
  fi
}

# Reverse of setup_claude_hooks: strip every confepo-managed entry from
# ~/.claude/settings.json (matched by helper name, exactly like the installer's
# own strip pass), leaving the user's hooks untouched. Without this, uninstall
# removes the helper symlinks but leaves hooks pointing at them — and every
# future Claude Code tool call fails with exit 127, forever.
remove_claude_hooks() {
  local settings="$HOME/.claude/settings.json"
  [ -f "$settings" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — remove the confepo-claude-* hook entries from $settings by hand"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  if jq '
      def strip($e; $needle):
        .hooks[$e] = ((.hooks[$e] // [])
          | map(select(([.hooks[]?.command] | map(. // "")
                        | any(test($needle))) | not)));
      if .hooks then
        ( strip("Notification";     "confepo-claude-notify")
        | strip("UserPromptSubmit"; "confepo-claude-notify")
        | strip("SessionEnd";       "confepo-claude-notify")
        | strip("PreToolUse";       "confepo-claude-blindgate")
        | .hooks |= with_entries(select(.value != []))
        | if .hooks == {} then del(.hooks) else . end )
      else . end
    ' "$settings" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    if cmp -s "$tmp" "$settings"; then
      rm -f "$tmp"   # nothing of ours in there
    elif [ "${DRY_RUN:-0}" = 1 ]; then
      rm -f "$tmp"; echo "  would remove confepo hooks from ~/.claude/settings.json"
    else
      mv "$tmp" "$settings" && ok "removed confepo hooks from ~/.claude/settings.json"
    fi
  else
    rm -f "$tmp"
    warn "could not update $settings — remove the confepo-claude-* hook entries by hand"
  fi
  return 0
}

setup_claude_mcp() {
  if ! command -v claude >/dev/null 2>&1; then
    info "Claude Code not installed — skipping MCP setup (get it at https://claude.com/claude-code)"
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    warn "Playwright MCP needs Node.js (npx). Install Node, then run:"
    warn "  claude mcp add --scope user playwright -- npx @playwright/mcp@latest"
    return 0
  fi
  if claude mcp list 2>/dev/null | grep -qi playwright; then
    ok "Playwright MCP already registered"
  elif claude mcp add --scope user playwright -- npx @playwright/mcp@latest >/dev/null 2>&1; then
    ok "registered Playwright browser MCP (claude mcp: playwright)"
  else
    warn "could not register Playwright MCP — run manually:"
    warn "  claude mcp add --scope user playwright -- npx @playwright/mcp@latest"
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
           setxkbmap pactl flameshot feh node fnm claude qrencode; do
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

# Stop the pure-LAN notification service before its unit symlink is removed, so
# uninstall never leaves a daemon running against a now-dangling symlink. Called
# from unlink_pkg for the 'lan' package (the one package with a live side effect).
teardown_lan_service() {
  command -v systemctl >/dev/null 2>&1 || return 0
  # Only act if the unit is actually known to the user manager (else nothing to do).
  systemctl --user cat confepo-lan.service >/dev/null 2>&1 || return 0
  if [ "${DRY_RUN:-0}" = 1 ]; then echo "  would stop + disable confepo-lan.service"; return 0; fi
  systemctl --user disable --now confepo-lan.service >/dev/null 2>&1 || true
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  ok "stopped confepo-lan.service"
}

# Remove confepo's symlinks for one package, then prune emptied app dirs.
unlink_pkg() {
  local pkg="$1" rel target f d
  local pkgdir="$CONFEPO_DIR/stow/$pkg"
  [ -d "$pkgdir" ] || { warn "no such package: $pkg"; return 1; }
  # Stop the LAN service while its unit symlink still resolves (before unlinking).
  [ "$pkg" = lan ] && teardown_lan_service
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
  # The unlink pass just removed the hook helpers from ~/.local/bin; the hooks
  # in ~/.claude/settings.json that point at them must go too.
  remove_claude_hooks
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
