# claude — transparently run Claude Code inside tmux, so the confepo LAN
# phone bridge can type replies into it (tmux send-keys is the only clean
# keystroke-injection path; a bare terminal window has none — see
# confepo-claude-inject). Inside tmux already (or with tmux missing, or with
# CONFEPO_CLAUDE_NO_TMUX set) it just runs claude as-is.
function claude --description "Claude Code, wrapped in tmux so phone replies can reach it"
    if set -q TMUX; or set -q CONFEPO_CLAUDE_NO_TMUX; or not command -q tmux; or not isatty stdout
        command claude $argv
    else
        # tmux joins its command args with spaces for `sh -c`, so escape each.
        # Both `--` sentinels matter: without them a claude flag like
        # --version is eaten by string join/escape themselves.
        #
        # No lingering sessions, by construction:
        #  - claude exits -> its only window closes -> the session dies (tmux
        #    default; tmux.conf sets no remain-on-exit/exit-empty overrides);
        #  - destroy-unattached (set from inside, first thing) -> closing the
        #    terminal window kills the session+claude too, exactly like a
        #    bare terminal would — nothing accumulates invisibly. This
        #    deliberately trades away detach-and-keep; run tmux yourself if
        #    you want persistence.
        set -l cmd (string join -- ' ' (string escape -- command claude $argv))
        tmux new-session -s "claude-$fish_pid" -- \
            "tmux set-option destroy-unattached on >/dev/null 2>&1; $cmd"
    end
end
