---
name: verify-web-change
description: Verificar cambios en aplicaciones web Next.js o Nuxt/Vue mediante los scripts y el gestor de paquetes reales del repositorio. Usar al terminar una implementación web, antes de entregar o publicar una rama, o cuando se pida ejecutar lint, tipos, tests, build, smoke test o comprobaciones de accesibilidad sin inventar comandos.
---

# Verificar un cambio web

## Preparar la verificación

1. Leer el `AGENTS.md` aplicable y conservar cambios ajenos.
2. Inspeccionar `git status`, el diff y los archivos afectados para acotar la prueba.
3. Detectar el gestor desde `packageManager` y los lockfiles. Usar el gestor declarado; no regenerar otro lockfile.
4. Leer los scripts del `package.json` raíz y del workspace afectado. Detectar Next.js, Nuxt o Vue desde las dependencias, no por el nombre del directorio.

## Ejecutar

Ejecutar primero las comprobaciones rápidas y después las costosas:

1. Formato en modo comprobación, solo si existe un script o configuración inequívoca.
2. Lint.
3. Typecheck.
4. Tests dirigidos al cambio; ampliar a la suite completa cuando el riesgo lo justifique.
5. Build de producción.
6. Smoke test en navegador para cambios de interacción, rutas o renderizado.

Preferir los scripts existentes. Si existe una configuración inequívoca pero no
un script, solo ejecutar directamente la herramienta en su modo oficial de
comprobación sin escritura; en caso contrario, indicarlo como cobertura
ausente. No inventar `pnpm test`, flags ni herramientas ni ejecutar un
formateador que reescriba archivos salvo que el usuario haya pedido corregirlos.

## Comprobar comportamiento

- Para UI, probar estado normal, carga, vacío, error y navegación por teclado cuando sean relevantes.
- Revisar consola y peticiones de red sin mostrar cookies, tokens ni contenido de `.env`.
- En Next.js, distinguir código servidor/cliente, hidratación y rutas App/Pages.
- En Nuxt, distinguir SSR/cliente, auto-imports, middleware y rutas de servidor.

## Entregar evidencia

Informar cada comando, resultado y duración aproximada. Separar fallos causados por el cambio de fallos preexistentes y terminar con un veredicto: listo, listo con advertencias o bloqueado.
