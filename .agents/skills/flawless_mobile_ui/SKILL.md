---
name: flawless-mobile-ui
description: Reglas y estándares de diseño móvil y multiplataforma en Flutter para garantizar interfaces de lujo 100% responsivas, con cero desbordamiento visual (Zero Overflow), manejo de pantallas táctiles, visores multimedia interactivos y arquitectura visual limpia.
---

# Directrices de Diseño Móvil Impecable (Flawless Mobile UI)

Esta skill define las reglas obligatorias de diseño, composición y adaptabilidad para todas las interfaces de usuario móviles y multiplataforma del proyecto **Trekos M Hotel**.

---

## 1. Regla de Oro: Cero Desbordamiento (Zero Overflow Guarantee)

1. **Nunca usar dimensiones fijas sin flexibilidad en filas (`Row`):**
   - Todo texto o contenedor de ancho variable dentro de un `Row` DEBE estar envuelto en `Flexible` o `Expanded` con `TextOverflow.ellipsis`.
   - Cuando se combinan textos largos y botones de acción en la misma fila horizontal, usar `FittedBox(fit: BoxFit.scaleDown)` o `Flexible` para que los elementos escalen automáticamente sin quebrar los bordes de pantalla.

2. **Densidad y Dimensiones de Botones Móviles:**
   - En botones colocados dentro de tarjetas de lista, utilizar `visualDensity: VisualDensity.compact` y `tapTargetSize: MaterialTapTargetSize.shrinkWrap` con padding horizontal controlado (`horizontal: 8` a `14`).
   - Mantener las etiquetas de los botones breves y directas (ej: *"Ver"*, *"Reservar"*, *"Detalles"*).

3. **Barras de Acción Inferiores (`bottomNavigationBar` / Sticky CTAs):**
   - Siempre envolver el contenido en `SafeArea`.
   - Asignar proporciones de `flex` balanceadas entre la columna de precios y el botón de acción (ej: `Expanded(flex: 5, ...)` y `Expanded(flex: 6, ...)`).
   - Aplicar `FittedBox(fit: BoxFit.scaleDown)` en los textos de precio y etiquetas de botones para garantizar que dispositivos de pantallas pequeñas (320px - 360px de ancho) no sufran desbordamientos.

---

## 2. Experiencia Multimedia & Alta Resolución (Media & Zoom)

1. **Visor Interactivo en Pantalla Completa:**
   - Toda galería o foto de producto/habitación debe soportar un modo de pantalla completa mediante `InteractiveViewer` con soporte para gestos táctiles: *pinch-to-zoom*, desplazamiento (*pan*), y navegación entre imágenes (*swipe*).
   - Incluir selector de miniaturas y contador de fotos (`1 / N fotos`) con botón de cierre accesible (`X`).

2. **Carga y Fallbacks de Imágenes:**
   - Todo `Image.network` debe contar con `loadingBuilder` o `errorBuilder` estilizados con el color corporativo y un ícono alusivo para evitar pantallas en blanco o errores visuales ante desconexiones.

---

## 3. Filtrado y Control de Búsqueda Reactivo

1. **Filtros Avanzados en Bottom Sheet:**
   - El ícono de ajuste (`tune`) en los buscadores debe abrir un modal interactivo con filtros por: rango de precios, categorías, capacidad, piso y servicios/amenities con multi-selección.
   - Proveer un botón de *"Limpiar / Restablecer"* y un indicador visual en el ícono del buscador cuando haya filtros activos.
   - El filtrado debe ejecutarse mediante estados del BLoC sin mutar colecciones directamente en la capa visual.

---

## 4. Coherencia Semántica de Estados

1. **Ocultamiento de Estados Operativos Internos:**
   - En la interfaz del huésped/cliente, nunca mostrar etiquetas crudas de gestión interna como *"Check-out pendiente"*, *"Sucia"*, *"En limpieza"*, *"Inspección"*, *"Mantenimiento"*, *"Bloqueada"*, *"Fuera de servicio"*.
   - Utilizar el mapeo de `estadoPublico`: mostrar únicamente **`Disponible`**, **`Ocupada`** (para reservadas u ocupadas) o **`No disponible`** (para cualquier otro estado operativo) con tonos sobrios y discretos para garantizar la mejor imagen de marca ante el cliente.
