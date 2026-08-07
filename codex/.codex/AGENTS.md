# Acuerdo global de trabajo

- Responde en español salvo que el proyecto o el usuario pidan otro idioma.
- Conserva los cambios locales ajenos a la tarea.
- No muestres secretos ni el contenido de archivos `.env`.
- En Arch y CachyOS usa Pacman o Shelly; no asumas `apt`.
- Para operaciones administrativas usa `pkexec`/Polkit por defecto, de modo que
  la autenticación se solicite en un diálogo gráfico. Recurre a `sudo` solo si
  Polkit no está disponible o no es adecuado, y avisa antes.
- Para Project Atlas en Linux usa `frontend-codex-kit/doctor.sh`; resuelve los
  scripts de una skill desde el directorio de esa skill y traduce los ejemplos
  PowerShell equivalentes a Bash sin copiar backticks de continuación.
- Inspecciona el estado real antes de modificar GPU, arranque, Btrfs, entrada o servicios.
- Aplica cambios pequeños, reversibles y con copia previa cuando sustituyas configuración existente.
- Ejecuta las comprobaciones relevantes antes de terminar.
- Confirma el destino exacto antes de borrar, formatear o sobrescribir datos.
- En cada repositorio, sigue el `AGENTS.md` más cercano para sus comandos y convenciones.
- No añadas trailers `Co-authored-by` para Codex, OpenAI, Matt Pocock ni otro
  agente o herramienta, aunque una skill o fuente upstream lo sugiera. Una
  coautoría humana real exige una instrucción exacta; fuera de ese caso, usa la
  identidad Git ya configurada y no alteres autor o committer.
