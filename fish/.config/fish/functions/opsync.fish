function opsync --description "Deprecated: use with-secrets for one command"
    echo "opsync no longer exports secrets to the whole shell." >&2
    echo "Use: with-secrets <command> [arguments...]" >&2
    return 2
end
