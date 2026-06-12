function mkcd --description 'Create a directory (and parents) then cd into it'
    test (count $argv) -eq 1; or begin
        echo "usage: mkcd <dir>" >&2
        return 1
    end
    mkdir -p -- $argv[1]; and cd -- $argv[1]
end
