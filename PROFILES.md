# Arquitectura de perfiles

Los perfiles se componen por ámbito, no por el nombre funcional de una
categoría. Así una aplicación de `media` o `files` puede ser común sin depender
de que alguien recuerde una excepción implícita.

## Fuentes de verdad

- `profiles.sh` declara una sola vez los módulos Stow comunes y los extras de
  `desktop` y `workstation`. `install.sh`, `just` y `scripts/stow-lint.sh` cargan
  esa misma definición.
- `packages.csv` usa `ámbito,categoría,paquete,origen`. El ámbito admite
  `common`, `desktop` o `workstation`; el origen admite `native` o `aur`.
- `flatpak-remotes.csv` declara `remoto,url` y `flatpaks.csv` declara
  `ámbito,categoría,app-id,remoto,rama`.
- `system-etc/` permanece fuera de los perfiles HOME y conserva su flujo de
  revisión, confirmación y backup independiente.

La categoría solo describe la función de un paquete. La selección efectiva es
`common + perfil`, tanto para Pacman/AUR como para Flatpak.

## Composición efectiva

| Ámbito | Contenido |
|---|---|
| `common` | shell, editores, navegador, Noctalia, aplicaciones base, Spotify, LocalSend, Micro, calculadora y Stremio |
| `workstation` | `hypr-laptop`, incluido eDP, touchpad, teclado y brillo del portátil antiguo |
| `desktop` | `hypr-desktop`, `gaming` y `backup`, incluidos monitores, NVIDIA y ajustes del hardware inspeccionado |

Los comandos base de Hyprland viven en `hypr-common`; cada perfil conserva solo
entrada, monitores, teclas y política de workspaces dependientes del hardware.
El launcher de Noctalia que espera DDC sigue siendo común porque se degrada a
eDP o a cero salidas externas sin imponer una topología de sobremesa.

## Flatpak y Stremio

Stremio se modela como `com.stremio.Stremio` desde `flathub/stable` para ambos
perfiles. En la auditoría del 2026-08-06 el remoto del host principal resolvía
la versión 1.1.4. No se fija ese número: el dato reproducible es la identidad,
el remoto y la rama estable, que puede avanzar sin reescribir los dotfiles.

El instalador añade Flathub e instala las aplicaciones en el ámbito del usuario;
no usa AUR ni inventa un paquete Pacman para Stremio. Esto evita sustituir la
aplicación publicada en Flathub por clientes comunitarios con otra procedencia.
Rollback exacto de la aplicación:

```bash
flatpak uninstall --user com.stremio.Stremio
```

El remoto de usuario se conserva porque puede ser compartido por futuras
aplicaciones. Retirarlo debe ser una decisión separada tras comprobar que está
vacío.

La migración de `dgpu` también es reversible: al aplicar cualquiera de los
perfiles, el antiguo enlace del módulo `fish` se mueve al mismo backup de Stow.
`desktop` crea después el enlace nuevo desde `hypr-desktop`; `workstation` deja
de exponer ese helper NVIDIA.

## Hallazgos conservados para una limpieza posterior

Los directorios `gtk/`, `kitty/`, `kvantum/`, `micro/` y `npm/` no pertenecen a
ningún perfil actual. No se añadieron automáticamente porque mezclan estado
heredado: enlaces GTK absolutos a Catppuccin, configuración de Kitty sin paquete,
Kvantum Catppuccin, temas antiguos de Micro y un prefijo npm con un HOME ajeno.
Micro sí es una aplicación común, pero su tema Project Atlas vivo lo genera
Noctalia; por eso su antiguo módulo Stow sigue excluido.

La limpieza futura puede retirar esos directorios tras confirmar que no quedan
consumidores. Mantenerlos fuera de `profiles.sh` evita desplegarlos por accidente.
