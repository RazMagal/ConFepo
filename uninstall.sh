#!/usr/bin/env bash
# ============================================================================
# confepo — uninstall / revert
#
#   ./uninstall.sh                 revert EVERYTHING: remove confepo symlinks
#                                  and restore your original dotfiles from backup
#   ./uninstall.sh i3 fish         revert only these package(s)
#   ./uninstall.sh --dry-run       preview what would change (alias: -n)
#   ./uninstall.sh --list          show what's linked + which backups exist (-l)
#   ./uninstall.sh --no-restore    remove symlinks but keep your hands off backups
#   ./uninstall.sh --from STAMP    restore from a specific ~/.confepo-backup/<STAMP>
#   ./uninstall.sh --shell         also reset the login shell back to bash
#   ./uninstall.sh --purge         also remove confepo's state (~/.config/confepo,
#                                  the git identity stub if you never edited it)
#
# Safe by design: only removes symlinks that point INTO this repo, never
# clobbers a file you currently have in place, and NEVER uninstalls system
# packages (remove those yourself if you want — they're listed in packages/).
# ============================================================================
set -euo pipefail

CONFEPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CONFEPO_DIR
# shellcheck source=lib/common.sh
. "$CONFEPO_DIR/lib/common.sh"

show_uninstall_help() {
  cat <<'EOF'
confepo — uninstall / revert

  ./uninstall.sh                 revert EVERYTHING: remove confepo symlinks
                                 and restore your original dotfiles from backup
  ./uninstall.sh i3 fish         revert only these package(s)
  ./uninstall.sh --dry-run       preview what would change (alias: -n)
  ./uninstall.sh --list          show what's linked + which backups exist (-l)
  ./uninstall.sh --no-restore    remove symlinks but keep your hands off backups
  ./uninstall.sh --from STAMP    restore from a specific ~/.confepo-backup/<STAMP>
  ./uninstall.sh --shell         also reset the login shell back to bash
  ./uninstall.sh --purge         also remove confepo's state (~/.config/confepo,
                                 the git identity stub if you never edited it)

Safe by design: only removes symlinks that point into this repo, never clobbers
a file you currently have in place, and never uninstalls system packages.
EOF
}

DRY_RUN=0; NO_RESTORE=0; DO_SHELL=0; DO_PURGE=0; DO_LIST=0; RESTORE_FROM=""
PKGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run)  DRY_RUN=1 ;;
    -l|--list)     DO_LIST=1 ;;
    --no-restore)  NO_RESTORE=1 ;;
    --from)        shift; RESTORE_FROM="${1:?--from needs a STAMP (see --list)}" ;;
    --shell)       DO_SHELL=1 ;;
    --purge)       DO_PURGE=1 ;;
    -h|--help)     show_uninstall_help; exit 0 ;;
    -*)            die "unknown option: $1 (try --help)" ;;
    *)             PKGS+=("$1") ;;
  esac
  shift
done
export DRY_RUN NO_RESTORE RESTORE_FROM

if [ "$DO_LIST" = 1 ]; then list_state; exit 0; fi
[ "$DRY_RUN" = 1 ] && info "DRY RUN — nothing will actually change"

if [ ${#PKGS[@]} -gt 0 ]; then
  for p in "${PKGS[@]}"; do
    step "Reverting package: $p"
    unlink_pkg "$p" || continue
    [ "$NO_RESTORE" = 1 ] || restore_pkg "$p"
  done
else
  uninstall_all
  [ "$DO_SHELL" = 1 ]  && { step "Reverting login shell"; revert_shell; }
  [ "$DO_PURGE" = 1 ]  && { step "Purging confepo state"; purge_state; }
fi

step "Done"
if [ "$DRY_RUN" = 1 ]; then
  echo "  (dry run — re-run without --dry-run to apply)"
else
  echo "  confepo symlinks removed."
  [ "$NO_RESTORE" = 1 ] && echo "  Backups left untouched in ~/.confepo-backup/ (restore manually if needed)."
  echo "  System packages were NOT removed (see packages/*.txt to remove any by hand)."
  [ "$DO_SHELL" = 0 ] && [ ${#PKGS[@]} -eq 0 ] && command -v fish >/dev/null 2>&1 \
    && echo "  Login shell unchanged — pass --shell to switch back to bash."
fi
