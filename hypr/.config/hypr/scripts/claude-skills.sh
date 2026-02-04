#!/bin/bash
set -euo pipefail
# Show Claude Code skills cheatsheet in rofi

skills=$(cat <<'EOF'
/catchup                  Inicio de sesión — carga cambios del branch actual
/handoff                  Antes de /clear — guarda estado en session-state.md
/commit                   Crear commit convencional sin atribución AI
/commit -m "mensaje"      Commit con mensaje específico
/review-pr                Review del PR en branch actual
/review-pr 42             Review del PR #42
/scaffold-component Btn   Genera componente Button (autodetecta Vue/React)
/scaffold-component Btn --with-tests          + test co-localizado
/scaffold-component Btn --with-tests --with-story   + test + story
/perf-audit               Auditoría de rendimiento (fork, no gasta contexto)
/a11y-audit               Auditoría accesibilidad WCAG 2.1 AA (fork)
EOF
)

echo "$skills" | rofi -dmenu -p "Claude Skills" -i -theme ~/.config/rofi/launchers/type-1/style-2.rasi -theme-str 'window { width: 750px; }'
