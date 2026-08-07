---
name: review-web-pr
description: Own review of a Next.js, Nuxt, or Vue branch or pull request, including checks against its specification. Use for review requests, branch comparisons, or `/review`; keep the task read-only unless the user separately requests a fix.
---

# Revisar una PR web

## Establecer el alcance

1. Leer las instrucciones del repositorio y comprobar el estado local.
2. Resolver la base desde los metadatos de la PR o el upstream; no asumir `main` si Git indica otra base.
3. Leer el diff completo y rastrear los caminos de ejecución afectados antes de opinar.
4. Mantener la revisión en solo lectura. No arreglar hallazgos salvo petición explícita.

## Revisar por riesgo

Priorizar, en este orden:

1. Corrección, regresiones y condiciones de carrera.
2. Límites de confianza, autenticación, autorización, validación y exposición de datos.
3. SSR, hidratación, caché, navegación y estados asíncronos.
4. Accesibilidad por teclado, foco, nombres accesibles y semántica.
5. Rendimiento medible: waterfalls, bundles, renders y consultas innecesarias.
6. Cobertura de pruebas y observabilidad.

Usar hasta tres subagentes solo cuando los ejes sean independientes y el diff lo justifique. Evitar comentarios puramente estilísticos, hipótesis sin camino de código y recomendaciones genéricas.

## Validar hallazgos

Reproducir o ejecutar la comprobación más pequeña que confirme cada riesgo. Consultar documentación primaria cuando el hallazgo dependa de una versión concreta de Next, Nuxt, Vue o una API de navegador.

## Informar

Listar hallazgos por severidad con archivo/línea, comportamiento observable, evidencia y corrección mínima. Si no hay hallazgos, decirlo claramente y mencionar riesgos residuales o pruebas no ejecutables.
