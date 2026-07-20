# confepo

A **smart, self-installing, self-updating** Linux dotfiles repo built around:

- **i3** — tiling window manager with gaps, a custom **i3blocks** status bar
  (LAN IP · WAN IP · CPU · RAM · disk · volume · battery · clock), a live
  **Hebrew ⇄ English** keyboard toggle with an always-accurate indicator, and a
  **low-battery watcher** that warns, then suspends before you lose work.
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

## Design notes

The non-obvious decisions, and what they cost. A dotfiles repo is mostly config
— these are the parts that are actually engineering.

**Lint targets are discovered, not listed.** CI finds every shell and Python
script by *shebang* (`grep -rlIE '^#!.*(bash|/bin/sh|env +sh)'`) rather than
from a hardcoded list of paths. Adding a new stow package can't silently escape
`bash -n` / `shellcheck` / `py_compile`, because nobody has to remember to
update a glob. Same reason `link_dotfiles()` enumerates `stow/*/` instead of
naming packages: **the only list is the filesystem.** Note this uses GNU `grep
-r`, which descends dotdirs — ripgrep skips them, and every script here lives
under `.local/` or `.config/`.

**Installing config means editing files you don't own.** `~/.claude/settings.json`
belongs to Claude Code, not confepo, so writing hooks into it can't be a blind
append — re-running would duplicate entries, and an older confepo's entries
would linger. The jq pass **strips every confepo-managed entry, then re-adds the
current ones**, which makes it idempotent *and* self-migrating in one step, and
leaves the user's own hooks untouched. Any tool that writes into shared config
needs this shape.

**Uninstall is the feature that earns trust.** It only removes symlinks that
resolve *into this repo*, never overwrites a file currently in place, and
restores the **oldest** backup of each file — because the oldest one is your
true pre-confepo original; the newest is just a previous confepo run. It also
tears down the `systemd --user` service, since leaving a daemon running against
a removed symlink is worse than not uninstalling at all. It never removes system
packages: those are yours.

**No `curl | sh`, and honest failure.** Tools not packaged on every distro
(`starship`, `eza`, the Nerd Font) install from GitHub release binaries verified
against the published `.sha256` sidecar. When a release ships no sidecar it
installs anyway but **warns that it's unverified** — the alternative was
pretending to a guarantee that isn't there.

**Privacy by disclosure policy, not by encryption.** Phone alerts can go over
Telegram, which transits a third party in plaintext. Encryption was built first
— and then deleted: a phone can't practically decrypt a bot message, so E2E
would have delivered unreadable blobs and bought nothing. What replaced it is
cheaper and actually holds: automated pushes are vague *by construction* (a
coarse status, never a path, message body, or project name), a deterministic
sanitizer strips paths/URLs/tokens as a backstop, and a written rule governs
anything an agent composes. The LAN transport — which never leaves the Wi-Fi —
is allowed to carry real detail, because the threat model is different. **The
same alert has two different bodies depending on where it's going.**

**The obvious implementation was annoying.** Claude Code's `Notification` hook
fires both when a session is *blocked on you* and when it merely *finished a
turn*. A single catch-all hook meant a chime after literally every response.
Splitting it by `matcher` — `permission_prompt` chimes, `idle_prompt` stays
silent but still lights the status bar — fixed it. The tell that this is the
right fix: it keys off a documented event type rather than pattern-matching the
notification text, which isn't a stable interface.

**A battery warning is a state machine, not an `if`.** The naive low-battery
check (`if pct <= 20: notify`) nags on every poll; the naive fix (a "warned"
flag) warns you once and then never again for the life of the daemon. The
watcher instead remembers the *highest level* it has announced this discharge
cycle and only acts on a strictly higher one — and **re-arms by clamping that
level down to whatever the charge has recovered to**, padded by a hysteresis
margin. One rule covers plugging in, topping up partially, and a reading that
merely wobbles across a threshold; there is no separate "is it charging" branch
to get wrong. Recover past ~25% and every warning is armed again; past ~15%
only the low one is spent.

**Phone-approving permissions is deliberately not built.** Notifications land on
your phone; replying and approving tool calls from it is designed but stopped.
Approving a permission prompt remotely removes the human-in-the-loop property
that made the prompt worth having, and it earns a real security review first —
scoped to approve/deny rather than arbitrary input, chat-ID allowlisted, and
rate-limited. Shipping it because it would demo well is the wrong trade.

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

### Get pinged when Claude needs you

When a Claude Code session finishes or is waiting for input, confepo can alert
you. All three are **opt-in and independent** — nothing fires until you set it up:

```bash
confepo sound test        # local chime on this machine's speakers (on by default)
confepo lan setup         # push to your phone over Wi-Fi — no cloud, any phone OS
confepo remote setup      # push to your phone via a Telegram bot (works off-network)
```

- **`sound`** plays a short freedesktop chime locally on the attention hook. Mute
  it with `CONFEPO_SOUND=0` (or in `~/.config/confepo/sound.conf`).
- **`lan`** runs a tiny local web server (a `systemd --user` service) that your
  phone opens as a web page on the same Wi-Fi; setup prints a QR code to scan.
  Nothing leaves your LAN, so the alert carries real detail. It is **manual-start
  only**: `confepo lan setup` just mints the token and shows the URL, and
  `confepo lan start` runs the server **for that session only** — it never
  auto-starts at login and is gone after a reboot until you ask again (the unit
  ships with no `[Install]` section, so it can't even be `enable`d by accident).
  Stop it early with `confepo lan stop`. iOS caveat: a **locked** iPhone can only
  be woken by a cloud push — LAN alerts land instantly only while the page is
  open (there's a "keep screen awake" toggle to help).
- **`remote`** uses a Telegram bot, which *does* wake a locked phone but transits
  a third party — so those messages are deliberately kept vague (a generic
  status, never file names, paths, or project names).

### Don't let the laptop die (low-battery watcher)

i3 ships no battery handling at all, and a red number in the status bar is
invisible when you're fullscreen, on another workspace, or away. So the i3
config starts `confepo-battery-watch`, a small polling daemon that escalates:

| Charge | What happens |
| ------ | ------------ |
| **20%** | normal desktop notification — plug in soon |
| **10%** | **critical**, non-expiring notification + the local chime |
| **5%**  | `systemctl suspend`, so you don't lose work |

```bash
confepo battery status    # charge, thresholds, what has already fired, is it running
confepo battery test      # dry-run the whole escalation — prints, never suspends
confepo battery stop      # stop the daemon for this session
```

It's a clean **no-op on desktops** (no `/sys/class/power_supply/BAT*`), only
warns while **discharging**, and never fires the same warning twice in one
discharge cycle. Charge back up and the warnings **re-arm** — but only past a
hysteresis margin (default +5%), so a wobbling reading or a loose charger can't
nag you every poll. i3's `exec_always` restarts it on every i3 reload; it
replaces its own previous instance rather than piling up daemons.

Everything is configurable in `~/.config/confepo/battery.conf` (sourced shell
vars, same as `sound.conf`):

```bash
CONFEPO_BATTERY_LOW=20             # first warning
CONFEPO_BATTERY_CRIT=10            # critical warning + chime
CONFEPO_BATTERY_EMERG=5            # emergency action
CONFEPO_BATTERY_EMERG_ACTION=""    # "" DISABLES suspend (you still get warned)
CONFEPO_BATTERY_INTERVAL=60        # seconds between polls
CONFEPO_BATTERY_REARM=5            # hysteresis margin for re-arming
CONFEPO_BATTERY=0                  # turn the whole watcher off
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

If you enabled `confepo lan`, uninstalling also stops and disables its
`systemd --user` service (so no daemon is left running against a removed
symlink). The saved token in `~/.config/confepo/lan.conf` is kept unless you add
`--purge`.

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
| `Super`+`Shift`+`E`  | Power menu (lock/suspend/logout/restart/shutdown) |

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
| `debugger`       | root-cause debugging (code, tests, or sims) — cause, not symptom |
| `frontend-prototyper` | fast, clean POC UIs (Vite + React + Tailwind, or one HTML file) |

**Skills** (`~/.claude/skills/`) — invoke by name:

| Skill | Does |
| ----- | ---- |
| `commit`           | stage + write a clean Conventional Commit |
| `review-changes`   | review the working diff before committing |
| `harden-shell`     | `bash -n` + shellcheck a script and fix the findings |
| `write-tests`      | add meaningful, deterministic tests (matches your framework) |
| `scaffold-poc`     | spin up a runnable frontend prototype |
| `new-stow-package` | scaffold a new dotfile package the confepo way |

### Chip design & verification

Tailored for RTL/DV work — SystemVerilog/UVM-aware, lint- and synthesis-conscious:

| Agent / Skill | For |
| ------------- | --- |
| `rtl-designer` (agent)        | synthesizable SV/Verilog/VHDL — FSMs, CDC, reset, latch-free `always_comb`/`always_ff` |
| `verification-engineer` (agent) | UVM testbenches, sequences, scoreboards, functional coverage, SVA, cocotb |
| `rtl-reviewer` (agent)        | HDL review: sim/synth mismatch, CDC, inferred latches, X-optimism, the classic bugs |
| `lint-rtl` (skill)            | Verible / Verilator `--lint-only` and fix the findings |
| `run-sim` (skill)             | compile + run (Verilator / Icarus / VCS / Questa / Xcelium / cocotb) and triage |
| `new-uvm-testbench` (skill)   | scaffold a UVM env (interface, agent, env, sequences, scoreboard, test, top) |

### Orchestrator instructions + the browser MCP

An **active `~/.claude/CLAUDE.md`** (global, all projects) tells the main
assistant *when* to reach for these — in particular the frontend loop: **build a
UI with the `frontend-prototyper` agent / `scaffold-poc` skill, then verify it
with the Playwright browser MCP** (open it, click around, screenshot) before
calling it done.

The installer registers that MCP for you when Claude Code + Node are present:

```bash
claude mcp add --scope user playwright -- npx @playwright/mcp@latest
```

(run automatically by `install.sh` / `confepo update`; it self-skips if `claude`
or `npx` is missing). So the orchestrator both *knows about* the agents/skills
and has the browser tool to act on them.

Add your own by dropping an `agents/<name>.md` or `skills/<name>/SKILL.md` into
`stow/claude/.claude/` and running `confepo link`. Edit the global instructions
in `stow/claude/.claude/CLAUDE.md`. Don't want any of it? `confepo uninstall claude`.

> Claude Code itself isn't installed by confepo — get it at
> <https://claude.com/claude-code>. **Node.js** (needed by the Playwright MCP and
> the Vite POCs) **is** installed, via [fnm](https://github.com/Schniz/fnm) — no
> sudo, latest LTS, auto-switching per project. fish loads it automatically.

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
    ├── tmux/        .config/tmux/tmux.conf
    ├── git/         .config/git/config
    ├── claude/      .claude/{agents/*,skills/*/SKILL.md,CLAUDE.md}
    ├── lan/         .config/systemd/user/confepo-lan.service · .local/lib/confepo/confepo-lan-server
    └── bin/         .local/bin/{confepo,confepo-lock,confepo-lang-toggle,confepo-notify-*,…}
```

### How the magic works

- **Symlinks:** [GNU Stow](https://www.gnu.org/software/stow/). Each folder in
  `stow/` mirrors your `$HOME`; `stow --restow` (re)links it idempotently.
- **Packages:** one logical list (`packages/*.txt`) is mapped to per-distro
  names in `lib/common.sh → pkg_name`, and only **missing** packages are
  installed. Tools not packaged everywhere have non-repo installers: `starship`,
  `eza`, and the Nerd Font fall back to **checksum-verified GitHub release
  binaries** (never `curl | sh`); `autotiling` installs via `pipx` (skipped with
  a warning if `pipx` is unavailable).
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
