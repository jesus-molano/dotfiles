# Linux adapter

- On Arch and CachyOS use Pacman or Shelly; never assume `apt`.
- For administrative operations use `pkexec`/Polkit so authentication appears
  in a graphical dialog. Use `sudo` only when Polkit is unavailable, and say so first.
- Inspect the real state before changing GPU, boot, Btrfs, input or services.
- The shell tool runs zsh or bash, not fish: quote globs and `=` in arguments
  (`--include='*.md'`). Use absolute paths; do not prefix commands with `cd`
  to the working directory.
- Commit with `git commit -F <file>` as its own command. Claude Code runs a
  plain `git commit` outside its sandbox, where the signing agent is reachable;
  a message built with `$(...)` or a here-doc keeps the command sandboxed.
