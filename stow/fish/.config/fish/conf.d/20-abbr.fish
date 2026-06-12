# conf.d/20-abbr.fish — abbreviations & aliases (interactive only)
#
# abbr  -> expands live on the command line, so the REAL command lands in
#          history and Ctrl-R / completions keep working. Used for shortcuts.
# alias -> used only when shadowing a command NAME with a modern replacement.
status is-interactive; or exit

# ---------------------------------------------------------------------------
# Modern CLI replacements (guarded — degrade gracefully if a tool is missing)
# ---------------------------------------------------------------------------
if type -q eza
    alias ls  'eza --group-directories-first --icons=auto'
    alias ll  'eza -lh  --group-directories-first --icons=auto --git'
    alias la  'eza -lah --group-directories-first --icons=auto --git'
    alias lt  'eza --tree --level=2 --icons=auto'
    alias l   'eza -lah --group-directories-first --icons=auto --git'
end
if type -q bat
    alias cat 'bat --paging=never'
else if type -q batcat
    alias cat 'batcat --paging=never'
end
type -q rg;   and alias grep rg
type -q duf;  and alias df   duf
type -q btop; and alias top  btop
type -q dust; and alias du   dust

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------
abbr -a ..    'cd ..'
abbr -a ...   'cd ../..'
abbr -a ....  'cd ../../..'
abbr -a c     clear
abbr -a e     '$EDITOR'
abbr -a md    'mkdir -p'
abbr -a path  'echo $PATH | tr " " "\n"'
abbr -a reload 'exec fish'

# ---------------------------------------------------------------------------
# git
# ---------------------------------------------------------------------------
abbr -a g     git
abbr -a gs    'git status -sb'
abbr -a ga    'git add'
abbr -a gaa   'git add --all'
abbr -a gc    'git commit -m'
abbr -a gca   'git commit --amend'
abbr -a gco   'git checkout'
abbr -a gcb   'git checkout -b'
abbr -a gb    'git branch'
abbr -a gp    'git push'
abbr -a gpf   'git push --force-with-lease'
abbr -a gl    'git pull'
abbr -a gf    'git fetch --all --prune'
abbr -a gd    'git diff'
abbr -a gds   'git diff --staged'
abbr -a glog  'git log --oneline --graph --decorate --all'
abbr -a gst   'git stash'
abbr -a gstp  'git stash pop'
abbr -a gcl   'git clone'

# ---------------------------------------------------------------------------
# docker / compose (only suggested if docker exists)
# ---------------------------------------------------------------------------
if type -q docker
    abbr -a d    docker
    abbr -a dc   'docker compose'
    abbr -a dcu  'docker compose up -d'
    abbr -a dcd  'docker compose down'
    abbr -a dcl  'docker compose logs -f'
    abbr -a dps  'docker ps'
    abbr -a dpsa 'docker ps -a'
end

# ---------------------------------------------------------------------------
# system / apt (debian-family convenience)
# ---------------------------------------------------------------------------
if type -q apt
    abbr -a update  'sudo apt update && sudo apt upgrade'
    abbr -a install 'sudo apt install'
    abbr -a search  'apt search'
end

# ---------------------------------------------------------------------------
# this repo
# ---------------------------------------------------------------------------
abbr -a up   'confepo update'
abbr -a dots 'cd (cat ~/.config/confepo/path)'
