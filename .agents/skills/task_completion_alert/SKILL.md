---
name: task-completion-alert
description: Reproduce la alerta sonora teeetooo.mp3 al finalizar tareas o solicitudes del usuario para notificarle auditivamente que el trabajo ha concluido.
---

# Alerta Sonora de Finalización de Tareas (Task Completion Sound Alert)

Esta skill define la regla y el procedimiento para reproducir la alerta sonora de confirmación al concluir tareas de desarrollo, refactorización, resolución de bugs o implementación de nuevas funcionalidades en el proyecto **Trekos M Hotel**.

---

## 1. Archivo de Audio Oficial

- **Ruta absoluta del audio:**
  `C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\.agents\skills\teeetooo.mp3`

- **Script automatizado de reproducción:**
  `C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\.agents\skills\play_alert.ps1`

---

## 2. Cuándo Disparar la Alerta

El asistente/agente DEBE reproducir esta alerta sonora en los siguientes momentos:
1. **Al finalizar la tarea o lote de tareas solicitadas por el usuario:** Justo después de completar los cambios en el código, ejecutar las pruebas y dejar el entorno en estado listo.
2. **Antes de emitir el mensaje final:** La llamada a la reproducción del audio debe ejecutarse mediante `run_command` justo antes de presentar el resumen final al usuario.

---

## 3. Procedimiento de Ejecución

Para reproducir el audio de alerta de manera limpia en el entorno Windows con PowerShell, ejecutar el script dedicado:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\.agents\skills\play_alert.ps1"
```

### Contenido del Script `play_alert.ps1`
```powershell
Add-Type -AssemblyName presentationCore
$player = New-Object System.Windows.Media.MediaPlayer
$audioFile = "C:\Users\Trekos\AndroidStudioProjects\trekos_m_hotel\.agents\skills\teeetooo.mp3"
$player.Open([System.Uri]$audioFile)
$player.Play()
Start-Sleep -Seconds 3
```

> [!NOTE]
> Se utiliza `System.Windows.Media.MediaPlayer` de WPF/PresentationCore para garantizar reproducción de archivos MP3 en segundo plano sin abrir ventanas emergentes ni reproductores externos molestos.
