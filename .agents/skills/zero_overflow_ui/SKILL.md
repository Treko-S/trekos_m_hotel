---
name: zero-overflow-ui
description: Reglas, patrones y estándares obligatorios para prevenir y eliminar errores críticos de desbordamiento en Flutter (RenderFlex overflowed by X pixels), garantizando interfaces adaptables a cualquier ancho de pantalla y factor de escala de texto.
---

# Prevención de Errores Críticos de Diseño: Zero Overflow UI

Esta skill establece las directrices arquitectónicas y patrones de maquetación en Flutter para garantizar que ninguna pantalla, diálogo, tarjeta o componente visual presente jamás el error crítico de desbordamiento con franjas amarillas y negras (**`RenderFlex overflowed by X pixels`**).

---

## 1. Análisis de la Causa Raíz (Caso Real)

En diálogos, tarjetas o resúmenes de datos, el error se produce típicamente al colocar dos o más widgets dentro de un `Row` con textos dinámicos sin restricciones de tamaño:

```dart
// ❌ CÓDIGO DEFECTUOSO (Produce 'RenderFlex overflowed by 32 pixels on the right'):
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text('Habitación:'),
    Text('${room.numero} (${room.tipoNombre})'), // <-- Explota si el nombre es largo
  ],
)
```

**Por qué ocurre:**
1. Un `Row` no impone límites de ancho máximo por defecto a sus hijos.
2. Si la suma de los anchos de los textos sobrepasa el ancho de la tarjeta o del diálogo (reducido por los márgenes y paddings), Flutter no puede acomodarlo y dispara el error crítico `RenderFlex overflowed`.
3. El fallo se agrava en pantallas pequeñas (320px - 360px) o cuando el usuario activa un tamaño de letra grande en los ajustes del sistema operativo (*TextScaleFactor*).

---

## 2. Reglas de Oro Inquebrantables

### Regla 1: Todo Texto Dinámico en `Row` DEBE estar en `Expanded` o `Flexible`
Cualquier contenido dinámico (nombres, títulos, descripciones, fechas compuestas, tipos de habitación, correos) que comparta fila con otros widgets DEBE envolverse en `Expanded` con truncado seguro:

```dart
// ✅ PATRÓN CANÓNICO INMUNE A DESBORDAMIENTOS:
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text(
      'Habitación:',
      style: TextStyle(color: Colors.grey, fontSize: 12),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        '${room.numero} (${room.tipoNombre})',
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  ],
)
```

---

### Regla 2: Cifras Monetarias y Precios con `FittedBox` + `Expanded`
Un `FittedBox` por sí solo dentro de un `Row` **no previene el desbordamiento** porque el `Row` no le proporciona límites finitos. Debe combinarse siempre con `Expanded`:

```dart
// ✅ CIFRAS MONETARIAS QUE SE ESCALAN AUTOMÁTICAMENTE:
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    const Text('Total Estadía:', style: TextStyle(color: Colors.grey, fontSize: 12)),
    const SizedBox(width: 8),
    Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${currencyFormat.format(monto)} Gs.',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    ),
  ],
)
```

---

### Regla 3: Diálogos y Modales SIEMPRE con Scroll Vertical
Cualquier `Dialog`, `AlertDialog` o contenedor emergente con múltiples filas de información debe envolver su contenido en un `SingleChildScrollView`. De lo contrario, en teléfonos pequeños, orientación horizontal (*landscape*) o al abrir el teclado virtual, se producirá `RenderFlex overflowed on the bottom`:

```dart
// ✅ ESTRUCTURA DE DIÁLOGO SEGURA:
Dialog(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  backgroundColor: Colors.white,
  child: SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Íconos, títulos, filas de resumen, botones
        ],
      ),
    ),
  ),
)
```

---

### Regla 4: Botones con Texto Flexible en Interfaces Móviles
Los botones dentro de tarjetas o modales deben tener etiquetas adaptables con `FittedBox`:

```dart
// ✅ BOTÓN INDESTRUCTIBLE:
FilledButton.icon(
  onPressed: () => ...,
  icon: const Icon(Icons.payment_rounded, size: 18),
  label: const FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      'Realizar Adelanto o Pago Ahora',
      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
    ),
  ),
)
```

---

### Regla 5: Filas de Acción Dual (Dos Botones en `Row`)
Cuando se presenten dos botones lado a lado, usar `Expanded` con proporciones de `flex`:

```dart
Row(
  children: [
    Expanded(
      flex: 1,
      child: OutlinedButton(...),
    ),
    const SizedBox(width: 8),
    Expanded(
      flex: 1,
      child: ElevatedButton(...),
    ),
  ],
)
```

---

## 3. Lista de Verificación Pre-Entrega (Checklist Anti-Overflow)

Antes de dar por finalizado cualquier diseño o ajuste de interfaz:
- [ ] ¿Hay algún `Row` con dos textos rígidos sin `Expanded`? **(Corregir de inmediato)**.
- [ ] ¿Los campos clave-valor tienen `maxLines: 1` y `overflow: TextOverflow.ellipsis`?
- [ ] ¿Los precios y montos usan `Expanded` + `Align` + `FittedBox(fit: BoxFit.scaleDown)`?
- [ ] ¿Los diálogos y popups cuentan con `SingleChildScrollView`?
- [ ] ¿Se verificó visualmente o en pruebas a 320px / 340px de ancho?

---

## 4. Test Automatizado de Regresión de Desbordamiento

Incluir en los tests de widgets la simulación de pantalla estrecha (340x700):

```dart
testWidgets('Zero Overflow Guarantee en pantallas estrechas de 340px', (WidgetTester tester) async {
  tester.view.physicalSize = const Size(340, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  bool hasOverflow = false;
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.toString().contains('A RenderFlex overflowed') ||
        details.toString().contains('OVERFLOWED')) {
      hasOverflow = true;
    }
    originalOnError?.call(details);
  };

  await tester.pumpWidget(miWidgetDePrueba);
  await tester.pumpAndSettle();

  expect(hasOverflow, isFalse, reason: 'No debe existir desbordamiento visual RenderFlex');
});
```
