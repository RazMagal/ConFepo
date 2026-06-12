# confepo

A **smart, self-installing, self-updating** Linux dotfiles repo built around:

- **i3** — tiling window manager with gaps, a custom **i3blocks** status bar
  (LAN IP · WAN IP · CPU · RAM · disk · volume · battery · clock) and a live
  **Hebrew ⇄ English** keyboard toggle with an always-accurate indicator.
- **fish** — autosuggestions, syntax highlighting, fuzzy history (`Ctrl-R`),
  abbreviations, the **starship** prompt and a curated plugin set (fisher).
- **Modern CLI tools** — `eza`, `bat`, `ripgrep`, `fd`, `fzf`, `zoxide`,
  `delta`, `btop`, `duf`, `tldr`, all pre-wired.
- **nano** — line numbers, syntax highlighting, sane editing defaults.
- **One-command install & update** that detects your distro, installs only
  what's missing, symlinks everything, and can pull future changes with a
  single word: `confepo update`.

Tuned for **Ubuntu/Debian** (tested on Ubuntu 24.04) and works on
**Arch / Fedora / openSUSE** too (package names are mapped per-distro; some
desktop extras are best-effort outside apt).

---

## Quick start

```bash
git clone https://github.com/RazMagal/ConFepo.git ~/confepo
cd ~/confepo
./install.sh
```

Then **log out and pick the "i3" session** at the login screen. Open a new
terminal and you're in a fully configured fish shell.

### Install options

| Command                     | What it does                                         |
| --------------------------- | ---------------------------------------------------- |
| `./install.sh`              | Everything: CLI tools + i3 desktop + dotfiles        |
| `./install.sh --no-desktop` | Shell + CLI tools only (skip the i3/X stack)         |
| `./install.sh --no-chsh`    | Don't change your default login shell                |
| `./install.sh --link-only`  | Only (re)create the dotfile symlinks                 |
| `make help`                 | List the make targets (`install`, `cli`, `update`…)  |

Re-running is always safe: existing files are backed up to
`~/.confepo-backup/<timestamp>/` before any symlink is created.

---

## The one-command update

After you edit configs (or pull changes someone else pushed), apply everything
locally with a single word from anywhere:

```bash
confepo update
```

That command will:

1. `git pull --ff-only` the repo (and warn you first if you have uncommitted
   local edits, since a fast-forward pull can't proceed over them — see
   [Editing tracked files](#editing-tracked-files-machine-local-overrides)),
2. install any **newly added** packages (only the missing ones),
3. re-symlink the dotfiles (backing up conflicts),
4. sync fish plugins (`fisher update`),
5. live-reload i3 and the status bar.

Other `confepo` subcommands: `link`, `install`, `uninstall`, `doctor`, `path`,
`edit [file]`. (`up` is also a fish abbreviation for `confepo update`.)

```bash
confepo doctor      # health check: which tools are present / missing
```

---

## Uninstalling / reverting

Changed your mind, or want to back out one app? `uninstall.sh` (a.k.a.
`confepo uninstall`) removes confepo's symlinks **and restores the original
dotfiles it backed up** during install — so you end up where you started.

```bash
confepo uninstall                # revert EVERYTHING: unlink + restore your originals
confepo uninstall i3 fish        # revert only these packages
confepo uninstall --dry-run      # preview exactly what would change (nothing yet)
confepo uninstall --list         # show what's linked + which backups exist
confepo uninstall --no-restore   # just remove symlinks; leave backups untouched
confepo uninstall --from <stamp> # restore from a specific ~/.confepo-backup/<stamp>
confepo uninstall --shell        # also reset your login shell back to bash
confepo uninstall --purge        # also remove confepo's own state (~/.config/confepo)
```

(`make uninstall`, `make unlink` — symlinks only, keep backups — and `make revert`
— dry-run preview — are equivalent shortcuts.)

It's deliberately conservative:

- only removes symlinks that point **into this repo** — your own files are never touched;
- **never overwrites** a file you currently have in place (restores only where the spot is empty);
- restores the **oldest** backup of each file (your true pre-confepo original);
- **never uninstalls system packages** — those are yours to remove (they're listed
  in `packages/common.txt` and `packages/desktop.txt`);
- backups live in `~/.confepo-backup/<timestamp>/` and are left there with
  `--no-restore`, or pick a specific one with `--from <timestamp>`.

---

## Editing tracked files (machine-local overrides)

The configs in `stow/` are git-tracked. You can edit them directly (they ARE the
symlink targets, so changes apply immediately) — but then `confepo update`'s
`git pull --ff-only` can't fast-forward over your uncommitted edits. `confepo
update` now **warns** when your tree is dirty; the clean workflow is to commit
your changes (or keep them on a personal branch) before pulling.

For **per-machine** tweaks (a second monitor, no battery, a different keyboard)
you don't want to commit, use the override hooks — both are git-ignored and
loaded **last**, so they win, and you never touch a tracked file:

| Layer | Drop your overrides in… | Loaded by |
| ----- | ----------------------- | --------- |
| i3    | `~/.config/i3/config.local`        | `include` at the end of the i3 config |
| fish  | `~/.config/fish/conf.d/99-local.fish` | fish auto-sources `conf.d/` |
| git   | `~/.config/git/config.local`       | `[include]` (created for you) |

confepo tracks **no secrets** — keep tokens/SSH keys out of the repo (use the
`*.local` files above or somewhere outside the repo entirely).

---

## Keyboard cheatsheet (i3)

`Super` is the mod key.

| Shortcut             | Action                              |
| -------------------- | ----------------------------------- |
| `Super`+`Enter`      | Terminal (Alacritty)                |
| `Super`+`D` / `Super`+`E` | App launcher (rofi)            |
| `Super`+`Tab`        | Window switcher                     |
| `Super`+`Space`      | **Toggle Hebrew ⇄ English**         |
| `Super`+`1…0`        | Switch workspace                    |
| `Super`+`Shift`+`1…0`| Move window to workspace            |
| `Super`+`Ctrl`+`←/→` | Prev / next workspace               |
| `Super`+`H/J/K/L`    | Focus left/down/up/right            |
| `Super`+`Shift`+`H/J/K/L` | Move window                    |
| `Super`+`F`          | Fullscreen                          |
| `Super`+`B` / `V`    | Split horizontal / vertical         |
| `Super`+`S` / `W` / `T` | Stacking / tabbed / toggle split |
| `Super`+`A`          | Focus parent container              |
| `Super`+`Shift`+`Space` | Toggle floating                  |
| `Super`+`Ctrl`+`Space`  | Focus floating ⇄ tiling          |
| `Super`+`-` / `Super`+`Shift`+`-` | Show / move to scratchpad |
| `Super`+`R`          | Resize mode (then `H/J/K/L`)        |
| `Super`+`Shift`+`S`  | Screenshot (flameshot)              |
| `Super`+`Esc`        | Lock screen                         |
| `Super`+`Shift`+`Q`  | Kill focused window                 |
| `Super`+`Shift`+`C` / `R` | Reload / restart i3            |
| `Super`+`Shift`+`E`  | Exit i3 (logout)                    |

Volume, brightness and media keys work out of the box.

---

## fish cheatsheet

- Type, then press **`↑`** for prefix history search, **`→`** to accept the
  grey autosuggestion, **`Ctrl-R`** for fuzzy history (fzf).
- Abbreviations expand live (so real commands land in history): `gs`, `ga`,
  `gc "msg"`, `gp`, `glog`, `..`, `...`, `ll`, `la`, `up` (update), `dots` (cd
  to the repo). Full list: `stow/fish/.config/fish/conf.d/20-abbr.fish`.
- `mkcd <dir>` create+enter a directory; `extract <archive>` unpack anything.

---

## Claude Code (agent personas & skills)

confepo also version-controls your [Claude Code](https://claude.com/claude-code)
setup, so the same agents and skills follow you to every machine. It manages
**only** `~/.claude/agents`, `~/.claude/skills`, and `~/.claude/commands` — your
`settings.json`, history, and projects are never touched (stow links the
individual files; `~/.claude` stays a real directory).

**Agent personas** (`~/.claude/agents/`) — delegate with the Agent tool / `@`:

| Agent | For |
| ----- | --- |
| `code-reviewer`  | adversarial, prioritized review — real bugs, `file:line`, not nits |
| `shell-hardener` | bash/`set -e`/quoting/shellcheck expert for scripts & dotfiles |
| `commit-crafter` | Conventional Commit messages from the actual diff |
| `explainer`      | concise, code-grounded explanations |

**Skills** (`~/.claude/skills/`) — invoke by name:

| Skill | Does |
| ----- | ---- |
| `commit`           | stage + write a clean Conventional Commit |
| `review-changes`   | review the working diff before committing |
| `harden-shell`     | `bash -n` + shellcheck a script and fix the findings |
| `new-stow-package` | scaffold a new dotfile package the confepo way |

Add your own by dropping a `agents/<name>.md` or `skills/<name>/SKILL.md` into
`stow/claude/.claude/` and running `confepo link`. To turn on global
preferences across all repos: `cp ~/.claude/CLAUDE.md.example ~/.claude/CLAUDE.md`
(kept opt-in on purpose). Don't want any of it? `confepo uninstall claude`.

> Claude Code itself isn't installed by confepo — get it at
> <https://claude.com/claude-code>.

---

## Layout

```
confepo/
├── install.sh              # bootstrap entrypoint (idempotent)
├── Makefile                # make install / cli / link / update / doctor
├── lib/common.sh           # distro detect, package abstraction, stow, fish…
│                           #   (shared by install.sh AND the confepo CLI)
├── packages/
│   ├── common.txt          # core CLI tools (one logical name per line)
│   └── desktop.txt         # i3 / X11 desktop stack
└── stow/                   # each subdir is a GNU Stow package mirroring $HOME
    ├── fish/        .config/fish/{config.fish,fish_plugins,conf.d,functions}
    ├── starship/    .config/starship.toml
    ├── alacritty/   .config/alacritty/alacritty.toml
    ├── i3/          .config/i3/config
    ├── i3blocks/    .config/i3blocks/{config,scripts/*}
    ├── picom/       .config/picom/picom.conf
    ├── dunst/       .config/dunst/dunstrc
    ├── rofi/        .config/rofi/config.rasi
    ├── nano/        .nanorc
    ├── git/         .config/git/config
    ├── claude/      .claude/{agents/*,skills/*/SKILL.md,CLAUDE.md.example}
    └── bin/         .local/bin/{confepo,confepo-lock,confepo-lang-toggle}
```

### How the magic works

- **Symlinks:** [GNU Stow](https://www.gnu.org/software/stow/). Each folder in
  `stow/` mirrors your `$HOME`; `stow --restow` (re)links it idempotently.
- **Packages:** one logical list (`packages/*.txt`) is mapped to per-distro
  names in `lib/common.sh → pkg_name`, and only **missing** packages are
  installed. Tools not packaged everywhere have non-repo installers: `starship`
  (official script) and `eza` + the Nerd Font (GitHub release binaries) fall
  back automatically; `autotiling` installs via `pipx` (skipped with a warning
  if `pipx` is unavailable).
- **fish plugins:** declared in `fish_plugins`, synced with `fisher update`.
- **The `confepo` CLI** is itself one of the symlinked scripts, so updating the
  repo updates the updater.

---

## Customizing

| Want to change…              | Edit…                                                   |
| ---------------------------- | ------------------------------------------------------- |
| i3 keybindings / autostart   | `stow/i3/.config/i3/config`                             |
| Status bar blocks            | `stow/i3blocks/.config/i3blocks/{config,scripts/*}`     |
| Layout toggle key / langs    | i3 `$mod+space` binding + `confepo-lang-toggle`         |
| Shell abbreviations          | `stow/fish/.config/fish/conf.d/20-abbr.fish`            |
| Prompt                       | `stow/starship/.config/starship.toml`                   |
| Terminal theme/font          | `stow/alacritty/.config/alacritty/alacritty.toml`       |
| Add a package                | append to `packages/common.txt` or `desktop.txt`        |
| Claude Code agents / skills  | `stow/claude/.claude/{agents,skills}/` then `confepo link` |

After editing, run `confepo link` (or `confepo update`) to apply. Set your git
identity in `~/.config/git/config.local` and a wallpaper with
`feh --bg-fill /path/to/image.jpg` (it persists across logins).

---

## Notes / troubleshooting

- **Pick the X11 session, not Wayland:** Ubuntu's login screen defaults to a
  Wayland GNOME session, but **i3 is X11-only**. At the greeter, click the gear
  and choose **i3** before logging in.
- **Multi-monitor:** arrange displays with `arandr`, then `autorandr --save
  <name>` — i3 runs `autorandr --change` on start and reapplies the matching
  profile automatically.
- **HiDPI / tiny text:** font sizes are fixed (i3 bar, `alacritty.toml`,
  `starship`). On a 4K panel, bump them, or set `Xft.dpi` in a
  `~/.config/i3/config.local`-driven Xresources.
- **No volume / dead volume keys:** the bar and keys use `pactl`; install
  `pipewire-pulse` (or `pulseaudio-utils`) if `pactl` is missing.
- **Hebrew toggle:** uses `setxkbmap` driven by `Super+Space`, with the active
  layout stored in `~/.cache/confepo-kblayout` so the bar indicator is exact.
  Prefer the classic `Alt+Shift`? Replace the `$mod+space` line in the i3
  config with `exec_always setxkbmap -layout us,il -option grp:alt_shift_toggle`
  (the indicator then needs `xkb-switch`, which isn't in Ubuntu's repos).
- **picom black screen in a VM:** change `backend = "glx"` to `"xrender"` in
  `stow/picom/.config/picom/picom.conf`.
- **Icons look like boxes:** the installer fetches FiraCode Nerd Font; if that
  download was skipped, install any Nerd Font and re-login.
- Backups of replaced files live in `~/.confepo-backup/<timestamp>/`.
