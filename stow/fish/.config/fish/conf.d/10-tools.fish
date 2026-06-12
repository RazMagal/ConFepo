# conf.d/10-tools.fish — initialise interactive tools (interactive only)
status is-interactive; or exit

# zoxide — smarter cd.  Use `z foo` to jump, `zi` for interactive pick.
type -q zoxide; and zoxide init fish | source

# starship — the prompt.  Config in ~/.config/starship.toml
type -q starship; and starship init fish | source

# fzf key bindings:
#   The fzf.fish plugin provides Ctrl-R (history), Ctrl-Alt-F (files),
#   Ctrl-Alt-L (git log), Ctrl-Alt-S (git status), Ctrl-Alt-P (processes).
#   If the plugin isn't installed yet, fall back to fzf's own bindings.
if not functions -q _fzf_search_history
    if type -q fzf
        # fzf >= 0.48 ships `fzf --fish`; older versions ship a key-bindings file.
        if fzf --fish >/dev/null 2>&1
            fzf --fish | source
        else
            for f in /usr/share/doc/fzf/examples/key-bindings.fish \
                     /usr/share/fish/vendor_functions.d/fzf_key_bindings.fish
                if test -r $f
                    source $f; and fzf_key_bindings
                    break
                end
            end
        end
    end
end
