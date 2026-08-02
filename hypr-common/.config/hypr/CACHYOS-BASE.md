# Base CachyOS versionada

Los módulos de `config/` se importaron de
`cachyos-hypr-noctalia 1.2.3-1` (`/etc/skel/.config/hypr/config`) el
2026-08-01. Se guardan en las mismas rutas que consume `hyprland.lua`; no hay
una segunda copia ni una ruta de carga implícita.

Después de actualizar CachyOS, compara sin sobrescribir:

```sh
hypr-check-cachyos-base
```

El manifiesto `cachyos-base.sha256` identifica cambios en el upstream aun cuando
nuestros módulos tengan personalizaciones deliberadas. Las novedades se revisan
y portan manualmente. Nunca se copian de `/etc/skel` sobre la configuración
activa de forma automática.
