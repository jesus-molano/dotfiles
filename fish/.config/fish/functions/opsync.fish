function opsync --description "Load 1Password env vars into environment"
    if not command -q op
        echo "1Password CLI not installed"
        return 1
    end

    op inject -i ~/.env.op | source
    and echo "1Password env loaded"
    or echo "Failed to load env"
end
