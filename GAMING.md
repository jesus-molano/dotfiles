# Gaming en el sobremesa CachyOS

Este perfil es exclusivo del host `desktop`. Mantiene a CHWD como propietario
del controlador NVIDIA y no despliega `system-etc` ni cambia explícitamente
servicios, kernel, initramfs, arranque o Btrfs. Shelly sí modifica paquetes
globales, que pueden aportar sus propios archivos y unidades del sistema.

## Stack gestionado

La categoría `gaming` de `packages.csv` instala:

| Componente | Función |
|---|---|
| `cachyos-gaming-meta` | Runtime multilib, UMU, Proton-CachyOS SLR y `wine-cachyos-opt` |
| `steam` | Steam y Proton oficial de Valve |
| `heroic-games-launcher-bin` | Epic, GOG y Amazon |
| `lutris` | Gestor de juegos y launchers no Steam |
| `faugus-launcher` | Lanzador sencillo basado en UMU |
| `gamescope` | Microcompositor opcional por juego |
| `mangohud`, `lib32-mangohud` | Métricas Vulkan/OpenGL de 64 y 32 bits |

El perfil añade además:

- `game-run`, que siempre ejecuta el juego mediante `game-performance`;
- `hypr-gaming`, que enfoca o abre Steam en el espacio 7;
- una configuración MangoHud discreta;
- una caché máxima de shaders NVIDIA de 12 GB mediante `environment.d`.

Consulta la selección exacta sin modificar nada:

```bash
just packages desktop
./install.sh desktop --list-packages
```

`workstation` excluye tanto estos paquetes como el módulo `gaming`.

## Ejecución por juego

Uso directo:

```bash
game-run -- juego argumentos
game-run --hud -- juego argumentos
game-run --gamescope -- juego argumentos
game-run --gamescope --hud -- juego argumentos
game-run --dry-run --gamescope --hud -- juego argumentos
```

`--gamescope` presenta una superficie virtual de 1920x1080 a 75 Hz. Cuando se
combina con `--hud`, `game-run` usa `gamescope --mangoapp`; sin Gamescope usa
`mangohud`. `--dry-run` imprime el comando escapado y no lanza nada.

Integración recomendada:

- Steam, en las opciones de lanzamiento del título:
  `game-run -- %command%`.
- Heroic, en el wrapper avanzado de cada juego: `game-run --`.
- Lutris, en **Opciones del sistema > Prefijo del comando**: `game-run --`.
- Faugus puede ejecutar el juego con UMU; añade el wrapper por título solo si
  su versión expone esa opción.

MangoHud y Gamescope son herramientas optativas, no mejoras automáticas. Activa
el HUD para medir y Gamescope cuando haga falta aislar resolución, escalado o
frame pacing. No se fuerzan globalmente HDR, tearing, Wine Wayland, DXVK ni un
límite de FPS.

Gamescope puede avisar de que no posee `CAP_SYS_NICE`. No se concede esa
capacidad globalmente: ArchWiki documenta que `setcap` puede hacer que se ignoren
variables Vulkan y romper el overlay de Steam. En este host a 75 Hz se conserva
la ruta estable con Ananicy y `game-performance`; solo se reconsiderará tras un
benchmark por juego que demuestre una mejora y verifique el overlay.

No combines `gamemoderun` con este flujo. `game-run` usa la utilidad
`game-performance` de CachyOS y el host ya ejecuta `ananicy-cpp`; GameMode y
Ananicy pueden competir al cambiar la prioridad del mismo proceso.

## Proton, Wine y launchers

En Steam conserva como valor global Proton estable de Valve o Proton
Experimental. Selecciona `proton-cachyos-slr` únicamente por juego cuando haya
una corrección o función concreta que lo justifique. No establezcas globalmente
`PROTON_ENABLE_WAYLAND`, `DXVK_HDR`, `PROTON_NO_NTSYNC` ni una versión GE.

Heroic, Lutris y Faugus deben preferir UMU con `proton-cachyos-slr` para juegos
Windows. `wine-cachyos-opt` queda disponible para aplicaciones que realmente
necesiten Wine fuera de Proton. Mantén cada prefijo separado y prueba cualquier
cambio primero en un solo título.

Los juegos con anti-cheat a nivel de kernel o sin habilitación por parte del
publisher pueden no funcionar, independientemente de la distribución, kernel o
versión de Proton. Comprueba el título antes de comprarlo o migrar una partida.

## Almacenamiento

La biblioteca activa debe permanecer en el NVMe Btrfs. La inspección del host
encontró `/home` en `/dev/nvme0n1p2` con Btrfs y una partición adicional
`/dev/sda2` en NTFS. No uses esa partición NTFS para bibliotecas de Steam/Proton:
permisos, nombres, enlaces y sensibilidad a mayúsculas pueden romper prefijos.

El doctor revisa la biblioteca principal y todas las rutas existentes de
`libraryfolders.vdf`. Btrfs pasa; NTFS falla; otro sistema de archivos genera un
aviso para revisión. Si Steam aún no se ha abierto, la ausencia de biblioteca es
solo informativa.

No muevas una biblioteca desde estos dotfiles. Haz cualquier migración desde
Steam, valida un juego y conserva una copia hasta comprobar los datos.

## Pantallas y mando

Los dos Philips 273V7 están configurados a `1920x1080@74.97` y con VRR
desactivado. Gamescope solicita 75 Hz para coincidir con esa señal. No se habilita
HDR, VRR ni tearing porque los paneles inspeccionados no justifican esos cambios.

El DualSense funciona mediante `hid-playstation`, por USB o Bluetooth. Su
ausencia en `just doctor desktop` es informativa, nunca un fallo. Decide Steam
Input por juego: algunos títulos ofrecen mejores iconos, giroscopio o hápticos
con entrada nativa y otros necesitan la traducción de Steam. `xpadneo` es para
mandos Xbox y no forma parte de este perfil. El doctor también comprueba que el
driver esté disponible y que Bluetooth esté activo; en el host desplegado pasan
ambas comprobaciones.

## Auditoría de firmware pendiente

Estado leído el 02-08-2026; no se modificó el firmware:

- placa ASUS TUF GAMING B550-PLUS (WI-FI), BIOS 3636 del 04-01-2026;
- 32 GiB mediante dos Kingston KF3200C16D4/16GX en A2/B2;
- el kit DDR4-3200 funciona a 2400 MT/s: DOCP está desactivado;
- la RTX 3060 Ti admite una región física redimensionable de hasta 8 GiB, pero
  BAR1 es de 256 MiB: ReBAR está desactivado.

DOCP y ReBAR son posibles mejoras posteriores de firmware, no tareas de estos
dotfiles. Si se evalúan, cambia una sola opción cada vez, registra antes una
medición repetible, prueba estabilidad de memoria/juegos y conserva la ruta de
reversión de la UEFI. No crees parámetros de kernel ni configuración de sistema
para simular ninguno de los dos.

El kernel actual también puede registrar:

```text
nvidia: unknown parameter 'NVreg_UsePageAttributeTable' ignored
```

El doctor lo muestra como aviso no fatal. No edites la configuración vendorizada
de NVIDIA desde este repositorio; CHWD debe seguir resolviendo el perfil y una
actualización del driver puede retirar el parámetro.

## Diagnóstico y rollback

```bash
just doctor desktop
just check desktop
just check gaming
```

El bloque gaming del doctor comprueba paquetes, CHWD, `nvidia-smi`, runtimes
NVIDIA/Vulkan de 32 bits, `game-performance`, Ananicy, GameMode coexistente,
monitores activos, bibliotecas Steam, driver/conectividad DualSense y las
variables de caché. Tras desplegar `environment.d`, cierra la sesión y vuelve a
entrar si el doctor aún no las ve cargadas en la sesión o el gestor de usuario.

Rollback de los dotfiles gaming:

```bash
just check gaming
just remove gaming
hyprctl reload
```

La retirada elimina únicamente los enlaces gestionados en `HOME`, incluido el
módulo opcional que registra `Hyper + G` y las reglas de los launchers; la recarga
lo retira también de la sesión activa. No desinstala paquetes ni borra juegos,
prefijos, partidas, bibliotecas o cachés. Revisa por separado con Pacman o Shelly
cualquier desinstalación de paquetes. Para volver al estado anterior, aplica de
nuevo el perfil `desktop` después de su simulación.

## Fuentes

Fuentes oficiales y upstream consultadas el 02-08-2026:

- [Gaming with CachyOS](https://wiki.cachyos.org/configuration/gaming/)
- [CHWD](https://wiki.cachyos.org/features/chwd/chwd/)
- [Valve Proton](https://github.com/ValveSoftware/Proton)
- [Proton-CachyOS](https://github.com/CachyOS/proton-cachyos)
- [UMU Launcher](https://github.com/Open-Wine-Components/umu-launcher)
- [Gamescope](https://github.com/ValveSoftware/gamescope)
- [ArchWiki: Gamescope y límites de CAP_SYS_NICE](https://wiki.archlinux.org/title/Gamescope)
- [MangoHud](https://github.com/flightlessmango/MangoHud)
- [Hyprland: monitores](https://wiki.hypr.land/Configuring/Monitors/) y
  [VRR](https://wiki.hypr.land/Configuring/Basics/Variables/)
- [Omarchy 3.8.4](https://github.com/basecamp/omarchy/releases/tag/v3.8.4),
  referencia de UX; su edición gaming no aporta benchmarks ni tuning equivalente

Fuentes comunitarias e independientes, con sus límites metodológicos:

- [Debate reciente de r/cachyos sobre RTX 3060 Ti, input lag y launch flags](https://www.reddit.com/r/cachyos/comments/1snzhnj/my_problem_with_cachyos_and_nvidia/),
  17-04-2026; experiencias contradictorias que apoyan empezar sin flags globales,
  usar `game-performance` y añadir cambios solo tras medir un juego;
- [Estado de NVIDIA en r/cachyos](https://www.reddit.com/r/cachyos/comments/1uiph6m/what_is_the_current_gaming_performance_on_nvidia/),
  29-06-2026; muestra la variación por título, sobre todo en DX12, y evita
  prometer que un sistema operativo gana siempre;
- [Ancient Gameplays: Windows frente a CachyOS/Bazzite/PikaOS](https://www.youtube.com/watch?v=8PtOGYdtiBU),
  publicada en 2026; comparativa AMD/NVIDIA útil como contrapunto, pero con hardware
  distinto de este host y sin convertir sus resultados en ajustes universales;
- [PC Games Hardware: Linux frente a Windows, 20 GPU](https://www.pcgameshardware.de/Linux-Software-26761/Specials/GPU-Index-Test-Grafikkarten-in-Spielen-vs-Winodws-1487614/),
  actualizado el 27-02-2026;
- [GamingOnLinux: estado del anti-cheat](https://www.gamingonlinux.com/guides/view/anticheat-check-which-competitive-games-actually-work-on-linux-steamos/),
  actualizado el 23-06-2026;
- [CachyOS frente a Omarchy: metodología y frame pacing](https://www.gnugent.com/cachyos-vs-omarchy-part-2-1-lows-frame-pacing-and-the-full-data),
  18-05-2026; muestra comunitaria pequeña, no una base para defaults globales;
- [ProtonDB](https://www.protondb.com/) y
  [Are We Anti-Cheat Yet?](https://areweanticheatyet.com/), reportes comunitarios
  que deben contrastarse con el estado actual del juego
