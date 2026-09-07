# Estándares de Diseño Móvil y Cero Overflow

1. **Responsividad Estricta:**
   - Prohibido dejar textos de ancho fijo dentro de filas horizontales `Row` sin `Expanded`, `Flexible` o `FittedBox`.
   - Todas las barras de acción inferiores (`bottomNavigationBar`) deben probarse para pantallas angostas (>= 320px de ancho).

2. **Acciones Visuales Claras:**
   - Los botones de tarjetas de habitaciones deben utilizar la etiqueta concisa **`Ver`** para dirigir al usuario a la vista completa y reservar desde adentro.
   - En la vista de detalle, habilitar zoom interactivo en pantalla completa con `InteractiveViewer`.

3. **Buscador y Filtros:**
   - El ícono de filtro (`tune`) en la barra de búsqueda debe abrir el modal de filtros avanzados (precio, tipo, camas, piso, servicios) conectado al BLoC.
