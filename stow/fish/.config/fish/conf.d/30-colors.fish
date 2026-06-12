# conf.d/30-colors.fish — prompt/pager colours & greeting (interactive only)
status is-interactive; or exit

# Dim grey autosuggestion ghost-text; readable command/error colours.
set -g fish_color_autosuggestion brblack
set -g fish_color_command         green
set -g fish_color_param           normal
set -g fish_color_error           red --bold
set -g fish_color_comment         brblack
set -g fish_color_quote           yellow
set -g fish_color_redirection     cyan

# The startup banner is the custom fish_greeting function in functions/.
# To disable it entirely:  functions --erase fish_greeting; set -U fish_greeting ''
