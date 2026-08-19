# Base CachyOS versionada

Los módulos de `config/` se importaron de
`cachyos-hypr-noctalia 1.2.5-1` (`/etc/skel/.config/hypr/config`) el
2026-08-19. Se guardan en las mismas rutas que consume `hyprland.lua`; no hay
una segunda copia ni una ruta de carga implícita.

La revisión 1.2.4 añadió zoom de cursor y cambió sus atajos numéricos de
workspaces. Se portó el zoom. La revisión 1.2.5 añadió Satty y propuso
`render.direct_scanout = 2`. Satty se adaptó al flujo de captura a contexto y
direct scanout se expone como experimento reversible, no como valor permanente.
El perfil conserva VRR desactivado y su distribución deliberada de ocho
espacios mediante letras porque ambos comportamientos dependen del hardware
real del sobremesa.

Después de actualizar CachyOS, compara sin sobrescribir:

```sh
hypr-check-cachyos-base
```

El manifiesto `cachyos-base.sha256` identifica cambios en el upstream aun cuando
nuestros módulos tengan personalizaciones deliberadas. Las novedades se revisan
y portan manualmente. Nunca se copian de `/etc/skel` sobre la configuración
activa de forma automática.
