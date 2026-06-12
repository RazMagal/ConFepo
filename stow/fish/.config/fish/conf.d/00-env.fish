# conf.d/00-env.fish — environment & PATH (runs for ALL fish sessions)

# Local binaries (shims, starship, eza fallback, pipx apps, confepo CLI) first.
fish_add_path -g ~/.local/bin ~/.cargo/bin

set -gx EDITOR nano
set -gx VISUAL nano
set -gx PAGER less
set -gx LESS '-R'

# Default fzf look (shared by the fzf.fish plugin bindings).
set -gx FZF_DEFAULT_OPTS '--height 45% --layout=reverse --border --info=inline'

# Prefer fd for fzf file/dir traversal when present (respects .gitignore, hidden).
if type -q fd
    set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
end

# Colourful, paged man pages via bat when available.
if type -q bat
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -gx MANROFFOPT -c
    set -gx BAT_THEME ansi
end
