function with-secrets --description "Run one command with 1Password references"
    if test (count $argv) -eq 0
        echo "Usage: with-secrets <command> [arguments...]" >&2
        return 2
    end
    if not command -q op
        echo "1Password CLI is not installed" >&2
        return 1
    end

    set -l env_file "$HOME/.env.op"
    if not test -f "$env_file"
        echo "1Password reference file not found: $env_file" >&2
        return 1
    end

    command op run --env-file "$env_file" -- $argv
end
