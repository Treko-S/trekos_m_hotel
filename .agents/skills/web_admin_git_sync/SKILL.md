---
name: web-admin-git-sync
description: Realiza automáticamente el commit limpio y la sincronización (push) con GitHub en web_admin al finalizar tareas o cambios en la web administrativa, previniendo bloqueos de secretos, garantizando que el árbol de trabajo quede limpio y libre de conflictos.
---

# Sincronización Automática de Git para Web Admin (Hotel 3 Vagos)

Esta skill establece la regla operativa y el flujo automatizado para registrar y sincronizar con GitHub todos los cambios realizados en el módulo de la **Web Administrativa** (`web_admin`), garantizando que no se generen errores de desincronización ni bloqueos por políticas de seguridad de GitHub.

---

## 1. Regla de Activación Obligatoria

El agente o asistente **DEBE ejecutar este procedimiento automáticamente** cuando:
1. Se haya creado, modificado, refactorizado o eliminado cualquier archivo dentro del directorio `c:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\web_admin\`.
2. Se concluya una tarea que afecte la interfaz, la lógica, los módulos o los estilos de la web administrativa.
3. Se ejecute antes de emitir la respuesta final y justo antes de reproducir la alerta sonora `teeetooo.mp3` (`task-completion-alert`).

---

## 2. Prevención de Bloqueos de Seguridad (GitHub Push Protection)

Antes de realizar el commit, es mandatorio verificar que ningún archivo de `web_admin` contenga secretos en texto plano que activen el **GitHub Push Protection** (código de error `GH013`):
- **Claves de Resend:** Nunca incluir cadenas directas del tipo `re_[a-zA-Z0-9_]{32}`. Utilizar variables de entorno (`window.RESEND_API_KEY`), invocación de la Supabase Edge Function `send-hotel-email`, o codificación segura en tiempo de ejecución (`atob('...')`).
- **Claves de Servicio / Privadas:** No exponer claves secretas con permisos de administración directa sin protección.

---

## 3. Procedimiento de Ejecución Automatizado

### Opción A: Script dedicado de PowerShell (Recomendado)
Ejecutar el script provisto en la skill:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\.agents\skills\web_admin_git_sync\scripts\sync_web_admin.ps1" -CommitMessage "tipo(alcance): descripcion clara del cambio"
```

### Opción B: Comandos Git Directos
Si se ejecutan comandos individuales mediante `run_command`:
```powershell
# 1. Verificar estado
git -C "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\web_admin" status

# 2. Agregar cambios
git -C "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\web_admin" add -A

# 3. Commitear con mensaje convencional
git -C "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\web_admin" commit -m "feat/fix(scope): descripcion"

# 4. Integrar cambios remotos con rebase
git -C "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\web_admin" pull --rebase origin main

# 5. Subir a GitHub
git -C "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\web_admin" push origin main
```

---

## 4. Verificación de Éxito

La sincronización se considera completada cuando:
1. El comando `git push origin main` retorna exit code `0`.
2. `git -C web_admin status` confirma:
   ```text
   On branch main
   Your branch is up to date with 'origin/main'.
   nothing to commit, working tree clean
   ```
3. Posteriormente se dispara la alerta sonora con `task-completion-alert`.
