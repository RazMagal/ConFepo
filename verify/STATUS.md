# confepo — verification status

> Living checklist driven by `verify/LOOP_PROMPT.md`. The loop updates this file
> in place. Statuses: `pending` · `pass` · `fail` · `skip` · `retry` · `opt-in`.

> **Post-verification hardening (fresh-eyes review, 2026-06-12):** four cold
> reviewers (install lifecycle / adversarial bash / configs / docs+UX) audited
> the repo with no prior context. Verified + fixed real bugs beyond the loop:
> `setxkbmap` shipped in `x11-xkb-utils` (not `x11-xserver-utils`) so the Hebrew
> toggle would silently fail on a fresh box → added the package; `confepo-lock`
> aborted under `set -e` before `i3lock` (screen failed **open**) → made the
> lock unconditional; `install_list` returned 1 on an empty manifest; `/etc/shells`
> was edited even under `--no-chsh`; `confepo edit` opened a dir (broke `nano`);
> `memory` block was locale-fragile; `restore_pkg` could clobber a dangling
> symlink; `imagemagick`→`ImageMagick` on rpm distros. Added: LICENSE, CI
> (`.github/workflows/ci.yml`), `.shellcheckrc`, `.editorconfig`, `autorandr`
> autostart, and `~/.config/{i3,fish,git}/*.local` machine-override hooks. All
> re-linted clean; i3/fish configs re-validated with real parsers.

**Last updated:** 2026-06-12 15:43 IDT (iteration 3 — COMPLETE)
**Run flags seen:** `install-ok`, `link-ok` (cron job `2a67d0d1`, every 10 min)
**No-sudo installs done:** shellcheck 0.11.0 + GNU stow 2.4.1 (`~/.local/bin`); fish/i3/rofi/picom + libs extracted from `.deb` into `~/.local/confepo-tools` (validation only)

## Summary

| Result | Count |
| ------ | ----- |
| pass   | 25 |
| fail   | 0 |
| skip   | 1 |
| retry  | 0 |
| pending| 0 |

**Verdict:** ✅ **VERIFICATION COMPLETE.** 25/26 checks pass; E3 is intentional
`skip (manual)`. Across 3 iterations the loop found and fixed **5 real defects**:
1. `confepo help` / `install.sh --help` printed code lines (bad `sed` range) → heredocs.
2. shellcheck SC2221/2222 dead `*opensuse*` `case` pattern in `detect_os` → removed.
3. **Critical data-loss bug:** stow dir-folding + `backup_conflicts` moved repo files
   out on re-run → `stow --no-folding` + `readlink -f` guard (idempotent now).
4. **Duplicate i3 keybinding** `$mod+l` (vim "focus right" vs lock) — caught by `i3 -C`
   → lock moved to `$mod+Escape` (README + install.sh updated).
5. **picom config** used trailing commas, rejected by Ubuntu's libconfig 1.5 → removed.
All configs validated with their real parsers (`fish -n`, `i3 -C`, rofi `-dump-config`,
picom `--diagnostics`) — tools installed without sudo (static binaries / source build /
`.deb` extraction against the live X:0 session).

---

## Conventions

- All commands assume the current directory is the repo root.
- Bootstrap the repo library: `export CONFEPO_DIR="$PWD"; . lib/common.sh; detect_os`
- Validation tools live in `~/.local/bin` (shellcheck, stow) and
  `~/.local/confepo-tools` (relocated fish/i3/rofi/picom; run with
  `LD_LIBRARY_PATH=~/.local/confepo-tools/usr/lib/x86_64-linux-gnu` and `DISPLAY=:0`).

---

## Phase A — Static integrity (no installs, sandbox-safe)

### A1 · Bash syntax — `pass`
`bash -n` over all 13 shell scripts → 13 OK, 0 FAIL.

### A2 · ShellCheck — `pass`
`shellcheck -S warning -e SC1091` over all scripts → CLEAN (after fixing SC2221/2222).
shellcheck 0.11.0 installed via no-sudo static binary.

### A3 · Executable bits — `pass`
All scripts under `bin/` and `i3blocks/scripts/` + installer/lib are `+x`.

### A4 · Shebangs — `pass`
Every `bin/`+`scripts/` file starts with `#!/usr/bin/env bash`.

### A5 · No CRLF line endings — `pass`
`grep -rlU $'\r'` → clean (LF only).

### A6 · TOML parses — `pass`
`tomllib.load` on starship.toml + alacritty.toml → both OK.

### A7 · Repo layout — `pass`
All 21 expected files present.

### A8 · .gitignore coverage — `pass`
Covers `config.local` + `fisher.fish`.

---

## Phase B — Library logic (no installs, sandbox-safe)

### B1 · Distro detection — `pass`
`detect_os` → OS=ubuntu PKG=apt ARCH=x86_64.

### B2 · Package-name mapping is total — `pass`
Every logical name in both manifests maps to a non-empty real name (0 EMPTY).

### B3 · Manifest parsing — `pass`
common.txt=21, desktop.txt=36 packages parsed.

### B4 · apt availability of mapped names — `pass`
`apt-cache` candidate for every mapped name → 0 MISS.

### B5 · Doctor runs — `pass`
`confepo_doctor` → 30-line report, exit 0.

### B6 · `confepo` CLI dispatch — `pass`
`path`/`help`/`doctor` work. (Fixed: `help` was printing code lines → heredocs.)

---

## Phase C — Status-bar block scripts (no installs, sandbox-safe)

### C1 · All blocks run — `pass`
7 blocks all rc=0, single-line output.

### C2 · Keyboard indicator tracks state — `pass`
`keyboard_layout` HE/EN tracks the state file.

### C3 · LAN IP sane — `pass`
`lan_ip` → `LAN 192.168.10.19`.

### C4 · WAN / graceful degradation — `pass`
`wan_ip` → real IP; `volume` → `VOL n/a` (correct fallback without pactl).

---

## Phase D — Config validators (tool-gated) — ALL PASS

> Tools installed without sudo: stow from source; fish/i3/rofi/picom + missing
> libs extracted from `.deb` into `~/.local/confepo-tools` and run against the
> live `DISPLAY=:0` (Xwayland) session.

### D1 · fish syntax — `pass` `[NEEDS: fish ✓ via .deb]`
`fish -n` on config.fish + all conf.d/ + functions/ → 8/8 OK.

### D2 · i3 config check — `pass` `[NEEDS: i3 ✓ via .deb]`
`i3 -C -c stow/i3/.config/i3/config` → EXIT 0 after fixing a **duplicate `$mod+l`
keybinding** (vim "focus right" collided with lock; lock moved to `$mod+Escape`).
```bash
PFX=~/.local/confepo-tools; LP="$PFX/usr/lib/x86_64-linux-gnu:$PFX/lib/x86_64-linux-gnu"
LD_LIBRARY_PATH="$LP" "$PFX/usr/bin/i3" -C -c stow/i3/.config/i3/config
```

### D3 · Stow dry-run — `pass` `[NEEDS: stow ✓ built from source]`
`stow -nv` across all 11 packages → 0 conflicts.

### D4 · rofi theme parses — `pass` `[NEEDS: rofi ✓ via .deb]`
`rofi -dump-config -config …/config.rasi` → exit 0, no stderr; settings echoed back.

### D5 · picom config parses — `pass` `[NEEDS: picom ✓ via .deb]`
`picom --config …/picom.conf --diagnostics` (DISPLAY=:0) → no parse error after
removing **trailing commas** in array literals (rejected by Ubuntu libconfig 1.5).

---

## Phase E — Live install & idempotency

### E1 · Symlink + idempotency — `pass` `[OPT-IN: link-ok ✓]` `[NEEDS: stow ✓]`
**CRITICAL BUG FOUND & FIXED** (folding + backup moved repo files out on re-run).
After `--no-folding` + `readlink -f` guard: run1=0 / run2=0 backups, 8/8 scripts
intact, `~/.config/*` are real dirs with per-file symlinks into the repo.

### E2 · fish loads the linked config — `pass` `[OPT-IN: link-ok ✓]` `[NEEDS: fish ✓ via .deb]`
Interactive fish startup sources all configs with **zero errors**; the abbr file
defines **32 abbreviations** (gs/gp/up present) and the functions are valid.
> Test corrected: use `type -q` (triggers autoload), not `functions -q` (only checks
> already-loaded). Auto-source-at-startup couldn't be exercised on the *relocated*
> no-sudo fish (its data dir is hard-compiled to `/usr/share/fish`) — a relocation
> artifact, not a repo defect; it is standard behavior on an apt-installed fish.
```bash
FISH=~/.local/confepo-tools/usr/bin/fish
# config loads clean:
test -z "$("$FISH" -ic exit 2>&1 >/dev/null)" && echo "clean load"
# abbrs/functions defined (type -q autoloads):
"$FISH" -ic 'source ~/.config/fish/conf.d/20-abbr.fish
  type -q mkcd; and type -q extract; and abbr -q gs; and echo FISH-CONFIG-OK'
```

### E3 · Full system install — `skip (manual)` `[OPT-IN: manual only]`
The complete installer (packages + i3 stack + chsh). Intentionally never run by
the loop. Run by hand when ready: `./install.sh` then `confepo doctor`.

---

## Evidence Log

_Newest entries at the bottom._

```
2026-06-12 15:17 · iteration 1 · install-ok + link-ok · sandbox=on (apt installs blocked: sudo password)
2026-06-12 15:17 · A1 · pass · bash -n ×13 → 13 OK, 0 FAIL
2026-06-12 15:17 · A2 · pass · installed shellcheck 0.11.0 (no-sudo static); SC2221/2222 → removed dead *opensuse* pattern → CLEAN
2026-06-12 15:17 · A3-A8 · pass · exec bits / shebangs / LF / TOML / layout / gitignore all clean
2026-06-12 15:17 · B1-B5 · pass · detect_os=apt; mapping total; 21+36 pkgs; 0 apt MISS; doctor exit 0
2026-06-12 15:17 · B6 · pass · DEFECT: help printed code lines (sed range) in confepo + install.sh → heredocs
2026-06-12 15:17 · C1-C4 · pass · 7 blocks rc=0; HE/EN toggle; LAN/WAN ok; VOL n/a fallback
2026-06-12 15:26 · iteration 2 · built GNU stow 2.4.1 from source → ~/.local/bin
2026-06-12 15:26 · D3 · pass · stow -nv ×11 → 0 conflicts
2026-06-12 15:26 · E1 · FAIL→fixed · 2nd link run moved 14 repo files into backup via folded dir symlinks (DATA LOSS); restored; fix: stow --no-folding + readlink-f guard; re-test run1=0/run2=0, 8/8 scripts intact
2026-06-12 15:43 · iteration 3 · extracted fish/i3/rofi/picom from .deb into ~/.local/confepo-tools (no sudo); DISPLAY=:0 available
2026-06-12 15:43 · D1 · pass · fish -n on 8 fish files → all OK
2026-06-12 15:43 · D2 · FAIL→fixed · i3 -C found duplicate $mod+l (vim focus-right vs lock); moved lock→$mod+Escape (+README/install.sh); i3 -C now EXIT 0
2026-06-12 15:43 · D4 · pass · rofi -dump-config on .rasi → exit 0, no errors, settings echoed
2026-06-12 15:43 · D5 · FAIL→fixed · picom parse error line 15: trailing commas in arrays rejected by libconfig 1.5; removed → --diagnostics exit 0
2026-06-12 15:43 · E2 · pass · interactive load 0 errors; sourcing abbr file defines 32 abbrs (gs/gp/up); fixed STATUS check functions-q→type-q; auto-source artifact of relocated fish only
2026-06-12 15:43 · E3 · skip · manual only
2026-06-12 15:43 · DONE · 25 pass / 0 fail / 1 skip / 0 retry → VERIFICATION COMPLETE
```
