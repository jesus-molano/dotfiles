function y --description "Yazi con cambio de directorio al salir" --wraps yazi
    set -l cwd_file (mktemp -t yazi-cwd.XXXXXX)
    or return 1

    command yazi $argv --cwd-file="$cwd_file"
    set -l yazi_status $status

    if read -z cwd < "$cwd_file"
        if test -n "$cwd"; and test "$cwd" != "$PWD"; and test -d "$cwd"
            builtin cd -- "$cwd"
        end
    end
    command rm -f -- "$cwd_file"
    return $yazi_status
end
