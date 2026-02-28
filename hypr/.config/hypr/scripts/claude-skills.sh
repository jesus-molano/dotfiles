#!/bin/bash
set -uo pipefail
# Show Claude Code skills cheatsheet + workflow in rofi

skills=$(cat <<'EOF'
── Flujo diario ──────────────────────────────────────────────────
/catchup                  Retomar contexto (lee YAML + git)
  ↓ trabajar...           Claude planifica si es complejo
/simplify                 Revisar código cambiado
/commit                   Commit convencional sin AI attribution
/review-pr                Auto-review antes de PR
/handoff                  Guardar estado (YAML + markdown)

── Skills ────────────────────────────────────────────────────────
/catchup                  Lee status YAML + git log + diff
/handoff                  Guarda estado en session-state.md + status.yaml
/commit                   Commit convencional sin atribución AI
/commit -m "mensaje"      Commit con mensaje específico
/simplify                 Revisa código cambiado: reuso, calidad, eficiencia
/review-pr                Review del PR en branch actual
/review-pr 42             Review del PR #42
/scaffold-component Btn   Genera componente (autodetecta Vue/React)
/perf-audit               Auditoría rendimiento (fork, no gasta contexto)
/a11y-audit               Auditoría accesibilidad WCAG 2.1 AA (fork)

── Agentes ───────────────────────────────────────────────────────
implementer (sonnet)      Ejecuta planes aprobados, fase por fase
code-reviewer (sonnet)    Review de código en profundidad
arch-advisor (opus)       Decisiones de arquitectura Vue/Nuxt, React/Next

── Hooks automáticos ─────────────────────────────────────────────
pre-edit-protect          Bloquea .env, lockfiles, secrets, .git/
post-edit-format          Formatea con Biome/Prettier si hay config
filter-output             vitest → --reporter=dot, tsc → --pretty false
post-compact-context      Re-inyecta reglas + git context (sesión + compact)
EOF
)

echo "$skills" | rofi -dmenu -p "Claude Skills" -i \
    -theme ~/.config/rofi/launchers/type-1/style-2.rasi \
    -theme-str 'window { width: 750px; }'
