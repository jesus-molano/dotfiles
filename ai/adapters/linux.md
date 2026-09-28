# Linux adapter

- On Arch and CachyOS use Pacman or Shelly; never assume `apt`.
- For administrative operations use `pkexec`/Polkit so authentication appears
  in a graphical dialog. Use `sudo` only when Polkit is unavailable, and say so first.
- Inspect the real state before changing GPU, boot, Btrfs, input or services.
