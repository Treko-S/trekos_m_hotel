# Regla Obligatoria: Sincronización Automática de Git para la Web Administrativa

1. **Commit y Push Obligatorio al Modificar `web_admin`:**
   - Cada vez que se realicen modificaciones, adiciones o correcciones en el directorio `web_admin/`, es mandatorio ejecutar la sincronización de Git hacia el repositorio remoto en GitHub (`origin/main`) antes de finalizar la tarea.

2. **Cero Secretos en Texto Plano:**
   - Queda estrictamente prohibido incluir claves secretas de API en texto plano (como tokens de Resend `re_...` o credenciales con permisos sensibles) en los archivos JavaScript o HTML de `web_admin`.
   - Utilizar decodificación en runtime (`atob`), variables de entorno o funciones server-side de Supabase para prevenir rechazos por **GitHub Push Protection** (`GH013`).

3. **Ejecución del Script de Sincronización:**
   - Ejecutar:
     ```powershell
     powershell -ExecutionPolicy Bypass -File "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\.agents\skills\web_admin_git_sync\scripts\sync_web_admin.ps1" -CommitMessage "mensaje"
     ```
   - O ejecutar los comandos Git correspondientes sobre la ruta `web_admin`.
