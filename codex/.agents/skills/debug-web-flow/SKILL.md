---
name: debug-web-flow
description: Reproducir y depurar flujos web completos en aplicaciones Next.js, Nuxt o Vue usando navegador, consola, red, logs y código. Usar ante errores de interfaz, SSR/hidratación, navegación, formularios, autenticación, APIs, estados asíncronos o fallos que cruzan frontend y backend.
---

# Depurar un flujo web

## Reproducir antes de cambiar

1. Leer instrucciones, estado Git y pasos aportados por el usuario.
2. Detectar framework, gestor de paquetes y comandos reales del repositorio.
3. Usar un entorno local, de prueba o staging y datos desechables. No ejecutar
   flujos de autenticación, formularios o persistencia contra producción salvo
   autorización explícita del usuario.
4. Levantar solo los servicios necesarios y registrar URL, datos de prueba y resultado observado sin revelar secretos.
5. Reproducir con pasos mínimos; capturar consola, red y logs relevantes.

Si la petición es solo de diagnóstico, no editar código.

## Aislar la causa

- Trazar desde la interacción hasta estado, petición, handler y persistencia.
- Separar cliente, servidor, SSR, hidratación, caché y middleware.
- Formular una hipótesis comprobable cada vez y buscar evidencia que pueda refutarla.
- No atribuir el fallo al framework ni a una dependencia sin confirmar la versión y el camino ejecutado.

## Corregir cuando esté autorizado

Aplicar el cambio más pequeño que resuelva la causa, conservar trabajo ajeno y añadir una regresión proporcional. No incluir refactors laterales ni degradar validaciones para hacer pasar la prueba.

## Verificar

Repetir el flujo original y al menos un caso negativo o límite. Ejecutar los scripts existentes de lint, tipos, tests y build que correspondan. Informar causa raíz, evidencia, archivos cambiados, comprobaciones y cualquier riesgo pendiente.
