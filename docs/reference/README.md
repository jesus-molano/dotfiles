# Referencias de configuración legacy

Estos archivos conservan preferencias antiguas que no tienen paridad en la
composición actual. No son módulos GNU Stow y el instalador no los despliega.

- `legacy-kitty.conf` conserva ajustes funcionales de Kitty. Noctalia genera
  su paleta e incluye el tema, pero no sustituye todas estas opciones.
- `legacy-kvantum.kvconfig` conserva la selección antigua de Kvantum. El tema
  Qt de Noctalia genera colores para qt5ct y qt6ct, no para Kvantum.

Ghostty y qt5ct/qt6ct son las rutas activas. Si Kitty o Kvantum vuelven a la
composición, migra estas preferencias mediante un módulo alcanzable, prueba la
paridad en un HOME temporal y solo entonces retira esta referencia.
