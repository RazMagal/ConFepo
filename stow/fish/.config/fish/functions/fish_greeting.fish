function fish_greeting --description 'confepo welcome line'
    set -l host (prompt_hostname)
    set_color brblack
    printf '  %s on %s — type `up` to update confepo, `confepo doctor` to check tools\n' \
        (whoami) $host
    set_color normal
end
