# Linux adapter

- On Arch and CachyOS use Pacman or Shelly; never assume `apt`.
- For administrative operations use `pkexec`/Polkit so authentication appears
  in a graphical dialog. Use `sudo` only when Polkit is unavailable, and say so first.
- Inspect the real state before changing GPU, boot, Btrfs, input or services.
- Quote globs and `=` in shell arguments (`--include='*.md'`).
- Commit with `git commit -F <file>` as its own command. Claude Code runs a
  plain `git commit` outside its sandbox, where the signing agent is reachable;
  a message built with `$(...)` or a here-doc keeps the command sandboxed.
  Write the message with the Write tool to a literal path in the repository
  (for example `.git/COMMIT_DRAFT`), never under `$TMPDIR`, and do not add
  `git -C` or `cd`: those forms stay sandboxed.
