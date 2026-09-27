# Adaptador Linux

- En Arch y CachyOS usa Pacman o Shelly; no asumas `apt`.
- Para operaciones administrativas usa `pkexec`/Polkit por defecto, de modo que
  la autenticación se solicite en un diálogo gráfico. Recurre a `sudo` solo si
  Polkit no está disponible o no es adecuado, y avisa antes.
- Inspecciona el estado real antes de modificar GPU, arranque, Btrfs, entrada o servicios.
