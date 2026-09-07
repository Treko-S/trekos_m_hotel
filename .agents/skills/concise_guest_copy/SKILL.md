---
name: concise-guest-copy
description: Reglas y directrices de redacción (UX Copywriting) para la app móvil: mensajes dirigidos a huéspedes y clientes deben ser simples, concisos, cálidos y directos, sin sobrecarga informativa, sin jerga técnica interna ni tecnicismos burocráticos innecesarios.
---

# Redacción y Mensajes al Cliente: Simple, Conciso y Directo (Concise Guest Copy)

Esta skill define el estándar obligatorio de comunicación, micro-copia (UX Copywriting) y redacción de mensajes en la aplicación móvil **Trekos M Hotel**, garantizando una experiencia de usuario prémium, intuitiva y libre de fricciones.

---

## 1. Principio Fundamental: Enfoque 100% en el Huésped

Los textos en pantalla están destinados al **huésped/cliente final**, NO al equipo de desarrollo, ni al administrador de sistemas, ni al recepcionista.

> [!IMPORTANT]
> **REGLA DE ORO:** Un mensaje en la app debe responder de inmediato a dos preguntas del usuario:
> 1. *¿Qué necesito saber ahora mismo?*
> 2. *¿Qué acción debo tomar?*
> Si una palabra o frase no aporta valor directo a la experiencia del huésped, **debe eliminarse**.

---

## 2. Errores Críticos que DEBEN EVITARSE (Anti-Patrones)

### ❌ 1. Jerga Técnica y Backend Interno
Jamás mencionar en pantallas de clientes términos de arquitectura técnica o paneles administrativos:
- **Prohibido:** *"El recepcionista debe haber registrado tu llegada en el panel web"*
- **Prohibido:** *"Validación de estado 'Ocupada' en la base de datos de Supabase"*
- **Prohibido:** *"Se actualizará la tabla folios en backend"*
- **✅ Correcto:** *"Disponible al registrar tu Check-in en recepción."*

### ❌ 2. Sobrecarga Legal y Burocrática (Text Walls)
Evitar abrumar al huésped con artículos de leyes tributarias, números de resolución o decretos interminables a menos que sea un contrato legal firmado.
- **Prohibido:** *"En estricto cumplimiento del Art. 85 de la Ley 6380/19 de modernización y simplificación impositiva..."*
- **✅ Correcto:** *"Precios con IVA incluido (10%). Factura oficial disponible al Check-out."*

### ❌ 3. Mensajes Extensos y Redundantes
No explicar lo obvio ni duplicar advertencias en un mismo cuadro de diálogo.

---

## 3. Patrones de Redacción Recomendados

| Contexto | ❌ Antes (Sobrecargado / Técnico) | ✅ Ahora (Simple, Claro y Conciso) |
| :--- | :--- | :--- |
| **Aviso de Check-in en Servicios** | *"Validación de Estadía: Para solicitar comidas, bebidas o amenidades y cargarlas a la cuenta, tu reserva debe estar en estado 'Ocupada' (el recepcionista ya debe haber registrado tu llegada física y entregado la llave en el panel web)..."* | **Servicio a la Habitación**<br>*"Disponible al registrar tu Check-in en recepción. Puedes explorar el menú mientras tanto."* |
| **Confirmación de Consumo** | *"¿Desea cargar Gs. 45.000 a su cuenta de la habitación para que el sistema actualice el folio y liquide al check-out?"* | **¿Cargar a la habitación?**<br>*"Gs. 45.000 se agregarán a tu cuenta y podrás abonarlos al hacer Check-out."* |
| **Botón de WhatsApp** | Extensa barra rectangular con *"Recepción 24/7 WhatsApp Oficial"* tapando la pantalla. | Botón circular compacto flotante con ícono oficial de WhatsApp. |
| **Políticas del Hotel** | Bloques de texto denso con resoluciones fiscales y convenios institucionales. | Puntos breves organizados con viñetas: Check-in 14:00, Check-out 11:00, Cancelación 48 hs. |
| **Notificación SnackBar** | *"Procesando solicitud de descarga y abriendo lector de documentos pdf..."* | *"Abriendo comprobante..."* |

---

## 4. Checklist Rápido de Validación de Textos

Antes de dar por bueno un texto o diálogo en la app móvil:
- [ ] ¿El texto cabe en 2 o 3 líneas como máximo en una pantalla estándar de móvil?
- [ ] ¿Eliminó referencias a "panel web", "base de datos", "Supabase" o roles internos del hotel?
- [ ] ¿El tono es cálido, respetuoso y orientado a la hospitalidad de lujo?
- [ ] ¿Usa lenguaje cotidiano y comprensible para cualquier viajero internacional?
