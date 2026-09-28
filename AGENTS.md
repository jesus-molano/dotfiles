# Dotfiles working map

- `main` is the canonical source; `~/.dotfiles` must point to it after a change is merged and validated.
- Composition uses no profiles: it combines base, capabilities, bundles and local preferences. Host state lives under XDG and is never versioned.
- Gaming bundles are portable and can be selected on any host. Keep hardware-specific adapters behind capabilities and explicit confirmation.
- Use `just check` for the hermetic simulation and `just plan` for the exact HOME preflight before deploying. Run `just apply` only after reviewing both. Never run Stow over every directory.
- Treat `system-etc/` separately: target `/etc`, prior backup and explicit confirmation.
- AI configuration lives in `ai/` and deploys with `just ai-plan`, `just ai-sync` and `just ai-check` (see `docs/ai.md`). Edit the source, then run `python3 scripts/render-ai.py`; never edit generated copies.
- Never read or show `.env`; run secrets only for the process that needs them through `with-secrets`.
- On CachyOS use Pacman or Shelly. CHWD owns the NVIDIA driver; never install generic branches or change ZRAM, boot, Btrfs, input or services without real inspection.
- Keep other people's changes and make small, reversible changes.
- Finish with the module's syntax checks, the Stow simulation, `git diff --check` and a summary of tests and unverifiable risks.
