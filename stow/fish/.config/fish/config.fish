# ~/.config/fish/config.fish  —  managed by confepo
#
# Kept intentionally thin. The real setup is split across conf.d/*.fish, which
# fish auto-sources (alphabetically) before this file:
#
#   conf.d/00-env.fish          PATH + environment (all sessions)
#   conf.d/10-tools.fish        zoxide / starship / fzf init (interactive)
#   conf.d/20-abbr.fish         abbreviations + aliases       (interactive)
#   conf.d/30-colors.fish       colors + greeting             (interactive)
#
# Custom functions live in functions/ and are lazy-loaded on first use.

if status is-interactive
    # everything interactive is handled in conf.d/ — keep this block empty.
end
