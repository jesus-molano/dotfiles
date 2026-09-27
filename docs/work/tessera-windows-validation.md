# Tessera y Kev: validación Windows

Comprobación real el 27 de septiembre de 2026 sobre la entrega publicada
`0bdff86ee6d28f3d1cd7d9b8e030d26815a6d1fd`, con las correcciones Windows de este
commit. No son resultados heredados del equipo Linux.

## Correcciones de portabilidad

- El checkout con `core.autocrlf=true` convirtió el parche a CRLF y `git apply`
  lo rechazó. El launcher normaliza CRLF a LF por stdin, primero con `--check`.
  `.gitattributes` fija LF para futuras materializaciones. El hash del servidor
  resultante permanece igual; no se cambia el parche contra truncado.
- La prueba de CRLF de Tessera convertía CRLF ya existentes a CRCRLF. Ahora
  normaliza antes de fabricar la entrada de prueba.
- `huggingface_hub 1.32.0` intentó crear un enlace durante la descarga concurrente
  y falló con WinError 1314. El launcher activa `HF_HUB_DISABLE_SYMLINKS=1` solo
  en Windows y solo para el proceso servidor. La dependencia usa copias;
  no requiere privilegios ni modificar políticas del equipo.

## Entorno y modelo

Windows 11 Pro x64, Intel Core 7 240H, 32 GB RAM, RTX 5060 Laptop de 8 GB,
driver 617.14. uv 0.12.19 y Python 3.13.15. Runtime aislado en
`%LOCALAPPDATA%\tessera\kev`, con upstream y checkpoint fijados por el launcher.
Se conservó el runtime parcial del primer intento y se recuperó aplicando el
parche normalizado y `uv sync --locked --no-dev --extra serve --python 3.13`.

`windows-cuda` instaló el wheel oficial fijado de torch 2.8.0+cu128.
`check` confirmó `cuda_build=12.8`, `cuda=true` y bf16. No se modificaron drivers.
Las fichas oficiales de Kev-4B declaran unos 9 GB para pesos y 14 GB con búferes;
no cabe con margen en esta GPU. Se mantiene Kev-0.8B, sin cuantización alternativa
ni cambio al runtime del PC de casa.

## API e integración reales

`GET /v1/models` confirmó
`jaredpalmer/kev-0.8b@9a45d25eb2ab761841196625383fa1dff0e56c1e`, dispositivo
`cuda`, backend `torch` y `bfloat16`.

Un estado de 70.002 tokens devolvió HTTP 422: límite 65.536. El contador de
inferencias permaneció en cero antes de la siguiente petición. Sin truncado.

Expenses-Log-App no está disponible en este PC. Se preparó un catálogo piloto
externo de alcance explícito sobre dos utilidades reales de un proyecto del
trabajo, con revisión limpia. No representa todo el proyecto ni instala un
catálogo dentro de él. Las 19 pruebas existentes de esas utilidades pasaron.
El proyecto quedó sin cambios. Este informe omite identidades, revisión y
contratos del proyecto; la evidencia primaria se conserva localmente en el PC
del trabajo.

Ambos motores recibieron todas las fichas del piloto, ocho opciones y el mismo
contexto, con igualdad de hashes verificada localmente.
Los archivos fuente completos permanecieron en la evidencia local.

| Motor | Decisión | Latencia cliente | Tokens entrada |
|---|---|---:|---:|
| Jev 1.13.0 | reuse | 0,547 s | 1787 |
| Kev-0.8B | insufficient_evidence | 2,266 s | 1274 |

La revisión local del agente respalda la compatibilidad del contrato elegido
por Jev con la tarea. Kev se abstuvo;
este caso no demuestra utilidad equivalente. No se ajustaron respuestas ni
filtraron fichas. Jev continúa como motor habitual.

Tras inferir, el snapshot de GPU mostraba 1878 MiB usados en total, incluidos
otros procesos; no es una medición de pico ni del consumo exclusivo del modelo.
El servidor registró una petición de inferencia y cero reintentos por OOM.

## Despliegue y comprobaciones

17 skills (16 propias y Playwright) y cinco roles por cliente en Windows.
Sesiones nuevas de Codex y Claude reconocieron Tessera y su enlace desde
engineering-flow. El despliegue utiliza el wrapper existente, copias y backups;
conserva preferencias y credenciales. Jev se autenticó con 1Password CLI y
`op run`, inyectando la credencial únicamente en el proceso. No se versionan
referencias de secretos ni respuestas brutas.

Pruebas Windows: Tessera 29 (1 omitida), launcher Kev 7 (1 omitida), sincronización
27 (3 omitidas); todas las ejecutadas pasan. La regresión del parche usa Git real,
LF/CRLF y rutas con espacios. `render-ai.py --check` y `git diff --check` correctos.
Revisión independiente de las correcciones completada sin hallazgos pendientes.

Para evitar desplegar bytecode generado por pruebas, ejecutar estas con
`python -B` y `PYTHONDONTWRITEBYTECODE=1`; revisar el plan. Excluir caches de forma
estructuralmente las cachés no formaba parte del commit Windows. La integración
posterior lo implementa en el snapshot de exportación del sincronizador,
manteniendo observación y backups completos.

Arranque manual: `python "$env:USERPROFILE\.agents\skills\tessera\scripts\kev-local.py" serve`.
Detener con Ctrl+C. Para el adaptador Kev, definir solo en el proceso
`TESSERA_KEV_ENDPOINT=http://127.0.0.1:8009/v1/systemone`. Sin autostart ni servicios.
