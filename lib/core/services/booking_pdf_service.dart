import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/hotel_search/domain/entities/booking.dart';

class BookingPdfService {
  static const MethodChannel _nativeChannel = MethodChannel('com.trekos.hotel/pdf_viewer');

  /// Genera el documento PDF oficial del comprobante de folio en memoria de manera 100% offline y pura
  static Future<Uint8List> generateReceiptPdf({
    required Booking booking,
    required String guestName,
    String? guestDoc,
    String? guestEmail,
    String? guestPhone,
  }) async {
    final pdf = pw.Document();

    final currencyFormat = NumberFormat('#,##0', 'es_PY');

    final total = booking.montoTotal;
    final paid = booking.folioTotalPagos;
    final remaining = booking.folioSaldoPendiente;

    // Cálculo impositivo SET Paraguay (IVA 10%)
    final int iva10 = (total / 11).round();
    final int gravada10 = (total - iva10).round();

    // Tipografías estándar vectoriales puras (sin llamadas HTTP ni dependencias de canal)
    final fontBold = pw.Font.helveticaBold();
    final fontSemiBold = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();

    // Colores Institucionales
    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFC5A059);
    const slateColor = PdfColor.fromInt(0xFF64748B);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const cardBgColor = PdfColor.fromInt(0xFFF8FAFC);
    const greenColor = PdfColor.fromInt(0xFF166534);
    const greenBgColor = PdfColor.fromInt(0xFFDCFCE7);
    const redColor = PdfColor.fromInt(0xFFB91C1C);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Barra Tricolor de la Bandera Paraguaya
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      height: 4,
                      color: const PdfColor.fromInt(0xFFDC2626), // Rojo
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      height: 4,
                      color: const PdfColor.fromInt(0xFFFFFFFF), // Blanco
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Container(
                      height: 4,
                      color: const PdfColor.fromInt(0xFF1E40AF), // Azul
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 2. Encabezado Institucional & Timbrado SET
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Columna izquierda: Membrete Hotel
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'HOTEL 3 VAGOS S.A.',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 16,
                          color: navyColor,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Servicios de Alojamiento y Hospedaje Turistico de Alta Gama',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: slateColor),
                      ),
                      pw.Text(
                        'Asuncion, Paraguay - Convenio Academico e Institucional UTCD',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: slateColor),
                      ),
                      pw.Text(
                        'Tel: +595 21 555-0199 | WhatsApp Oficial: +595 993 554920',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: slateColor),
                      ),
                    ],
                  ),

                  // Columna derecha: Recuadro Legal SET
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: cardBgColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: borderColor, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RUC: 80092341-2',
                          style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor),
                        ),
                        pw.Text(
                          'Timbrado No: 16789423',
                          style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                        ),
                        pw.Text(
                          'Validez: 01/01/2026 al 31/12/2026',
                          style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'COMPROBANTE OFICIAL DE FOLIO',
                          style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: goldColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: borderColor, thickness: 0.8),
              pw.SizedBox(height: 10),

              // 3. Tarjetas Informativas: Titular y Estadía
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Tarjeta Huésped
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: cardBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor, width: 0.6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TITULAR DE LA RESERVA / HUESPED',
                            style: pw.TextStyle(font: fontBold, fontSize: 8, color: navyColor),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            guestName.isNotEmpty ? guestName : 'Kevin Santacruz',
                            style: pw.TextStyle(font: fontSemiBold, fontSize: 9.5, color: navyColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'C.I. / RUC: ${guestDoc ?? '4.850.123-K'}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                          ),
                          pw.Text(
                            'Correo: ${guestEmail ?? 'cliente@hotel3vagos.com'}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                          ),
                          pw.Text(
                            'Telefono: ${guestPhone ?? '+595 993 554920'}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),

                  // Tarjeta Reserva
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: cardBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor, width: 0.6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DATOS DE HOSPEDAJE & ESTADIA',
                            style: pw.TextStyle(font: fontBold, fontSize: 8, color: navyColor),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Habitacion ${booking.habitacionNumero} (${booking.habitacionTipo})',
                            style: pw.TextStyle(font: fontSemiBold, fontSize: 9.5, color: navyColor),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Codigo Reserva: ${booking.codigoReserva}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                          ),
                          pw.Text(
                            'Check-in: ${booking.checkInPrevisto} | Check-out: ${booking.checkOutPrevisto}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                          ),
                          pw.Text(
                            'Duracion: ${booking.noches} noche(s) - ${booking.cantidadHuespedes} Huesped(es)',
                            style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 4. Detalle de Cargos de la Estadía
              pw.Text(
                '1. DETALLE DE CARGOS Y CONCEPTOS FACTURABLES',
                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor),
              ),
              pw.SizedBox(height: 5),

              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(5),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2.5),
                  3: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: navyColor),
                    children: [
                      _buildTableHeaderCell('Concepto / Servicio', fontBold),
                      _buildTableHeaderCell('Cantidad', fontBold, align: pw.TextAlign.center),
                      _buildTableHeaderCell('Tarifa Noche', fontBold, align: pw.TextAlign.right),
                      _buildTableHeaderCell('Subtotal (Gs.)', fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell(
                        'Alojamiento Hab. ${booking.habitacionNumero} (${booking.habitacionTipo})\nPeriodo: ${booking.checkInPrevisto} al ${booking.checkOutPrevisto}',
                        fontRegular,
                      ),
                      _buildTableCell('${booking.noches} noche(s)', fontRegular, align: pw.TextAlign.center),
                      _buildTableCell(
                        '${currencyFormat.format((total / booking.noches).round())} Gs.',
                        fontRegular,
                        align: pw.TextAlign.right,
                      ),
                      _buildTableCell(
                        '${currencyFormat.format(total)} Gs.',
                        fontSemiBold,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 5. Historial de Pagos & Señas Registradas
              pw.Text(
                '2. PAGOS, SENAS Y ANTICIPOS REGISTRADOS',
                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor),
              ),
              pw.SizedBox(height: 5),

              pw.Table(
                border: pw.TableBorder.all(color: borderColor, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(4.5),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
                    children: [
                      _buildTableHeaderCell('Fecha', fontBold),
                      _buildTableHeaderCell('Concepto del Pago', fontBold),
                      _buildTableHeaderCell('Canal / Medio', fontBold),
                      _buildTableHeaderCell('Estado', fontBold, align: pw.TextAlign.center),
                      _buildTableHeaderCell('Abonado (Gs.)', fontBold, align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildTableCell(booking.checkInPrevisto, fontRegular),
                      _buildTableCell(
                        paid >= total
                            ? 'Liquidacion Total de Estadia'
                            : 'Sena / Garantia de Reserva (${((paid / (total > 0 ? total : 1)) * 100).round()}%)',
                        fontRegular,
                      ),
                      _buildTableCell(
                        booking.canalVenta.isNotEmpty ? '${booking.canalVenta} - Online' : 'App Movil - Tarjeta/QR',
                        fontRegular,
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Center(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: const pw.BoxDecoration(
                              color: greenBgColor,
                              borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                            ),
                            child: pw.Text(
                              paid > 0 ? 'ACREDITADO' : 'PENDIENTE',
                              style: pw.TextStyle(font: fontBold, fontSize: 7, color: greenColor),
                            ),
                          ),
                        ),
                      ),
                      _buildTableCell(
                        paid > 0 ? '- ${currencyFormat.format(paid)} Gs.' : '0 Gs.',
                        fontSemiBold,
                        align: pw.TextAlign.right,
                        textColor: greenColor,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 6. Liquidación Impositiva SET & Estado de Cuenta
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Caja Izquierda: Liquidación IVA SET
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: cardBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor, width: 0.6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'LIQUIDACION DEL IVA (Art. 85 Ley 6380/19 SET)',
                            style: pw.TextStyle(font: fontBold, fontSize: 8, color: navyColor),
                          ),
                          pw.SizedBox(height: 4),
                          _buildTaxRow('Gravadas 10%:', '${currencyFormat.format(gravada10)} Gs.', fontRegular),
                          _buildTaxRow('Gravadas 5%:', '0 Gs.', fontRegular),
                          _buildTaxRow('Exentas:', '0 Gs.', fontRegular),
                          pw.Divider(color: borderColor, thickness: 0.5),
                          _buildTaxRow(
                            'TOTAL LIQUIDACION IVA 10%:',
                            '${currencyFormat.format(iva10)} Gs.',
                            fontBold,
                            color: navyColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),

                  // Caja Derecha: Estado de Cuenta & Saldo
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: cardBgColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: borderColor, width: 0.6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ESTADO DE CUENTA & TOTALES',
                            style: pw.TextStyle(font: fontBold, fontSize: 8, color: navyColor),
                          ),
                          pw.SizedBox(height: 4),
                          _buildTaxRow('Total Estadia:', '${currencyFormat.format(total)} Gs.', fontRegular),
                          _buildTaxRow(
                            'Total Pagado / Sena:',
                            paid > 0 ? '- ${currencyFormat.format(paid)} Gs.' : '0 Gs.',
                            fontRegular,
                            color: greenColor,
                          ),
                          pw.Divider(color: borderColor, thickness: 0.5),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'SALDO PENDIENTE:',
                                style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor),
                              ),
                              pw.Text(
                                remaining <= 0 ? '0 Gs. (SALDADO)' : '${currencyFormat.format(remaining)} Gs.',
                                style: pw.TextStyle(
                                  font: fontBold,
                                  fontSize: 10,
                                  color: remaining <= 0 ? greenColor : redColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // 7. Pie de Página y Firmas de Recepción
              pw.Divider(color: borderColor, thickness: 0.8),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Documento emitido electronicamente por el Sistema Hotel 3 Vagos.',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7, color: slateColor),
                      ),
                      pw.Text(
                        'Valido como comprobante formal de reserva, foliatura y garantia de hospedaje.',
                        style: pw.TextStyle(font: fontRegular, fontSize: 7, color: slateColor),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: borderColor, width: 0.6),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      'Firma & Sello de Recepcion / Caja',
                      style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: navyColor),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Guarda el comprobante PDF en la carpeta pública de Descargas Y en la caché de la app para apertura inmediata
  /// Retorna las rutas y nombres
  static Future<Map<String, dynamic>> saveReceiptPdfToDownloads({
    required Booking booking,
    required String guestName,
    String? guestDoc,
    String? guestEmail,
    String? guestPhone,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      booking: booking,
      guestName: guestName,
      guestDoc: guestDoc,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
    );

    final cleanCode = booking.codigoReserva.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final fileName = 'Comprobante_Hotel3Vagos_$cleanCode.pdf';

    String? publicDownloadPath;
    String? appCachePath;

    // 1. Guardar en carpeta pública de Descargas de Android (/storage/emulated/0/Download)
    if (Platform.isAndroid) {
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download');
        if (publicDownloadDir.existsSync()) {
          final testFile = File('${publicDownloadDir.path}/$fileName');
          await testFile.writeAsBytes(pdfBytes, flush: true);
          publicDownloadPath = testFile.path;
        }
      } catch (_) {}
    }

    // 2. Guardar copia en la carpeta de caché/documentos de la app (garantizado para FileProvider)
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/$fileName');
      await cacheFile.writeAsBytes(pdfBytes, flush: true);
      appCachePath = cacheFile.path;
    } catch (_) {
      final docDir = await getApplicationDocumentsDirectory();
      final docFile = File('${docDir.path}/$fileName');
      await docFile.writeAsBytes(pdfBytes, flush: true);
      appCachePath = docFile.path;
    }

    final safeCachePath = appCachePath;
    final finalPath = publicDownloadPath ?? safeCachePath;

    return {
      'path': finalPath,
      'cachePath': safeCachePath,
      'fileName': fileName,
      'bytes': pdfBytes,
    };
  }

  /// Abre el archivo PDF externamente disparando el selector nativo del sistema ("Abrir con")
  static Future<bool> openPdf(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    // 1. Intentar con canal nativo directo de Android (despliega Intent.createChooser "Abrir con")
    if (Platform.isAndroid) {
      try {
        final nativeOk = await _nativeChannel.invokeMethod<bool>('openPdfExternal', {'filePath': filePath});
        if (nativeOk == true) return true;
      } catch (_) {}
    }

    // 2. Fallback con OpenFilex indicando explícitamente el tipo application/pdf
    try {
      final result = await OpenFilex.open(filePath, type: 'application/pdf');
      if (result.type == ResultType.done) return true;
    } catch (_) {}

    return false;
  }

  /// Genera, guarda en Descargas y abre inmediatamente el PDF con el menú "Abrir con" del sistema
  static Future<Map<String, dynamic>> saveAndOpenPdf({
    required Booking booking,
    required String guestName,
    String? guestDoc,
    String? guestEmail,
    String? guestPhone,
  }) async {
    final result = await saveReceiptPdfToDownloads(
      booking: booking,
      guestName: guestName,
      guestDoc: guestDoc,
      guestEmail: guestEmail,
      guestPhone: guestPhone,
    );

    final String openPath = (result['cachePath'] as String?)?.isNotEmpty == true
        ? result['cachePath'] as String
        : (result['path'] as String? ?? '');

    if (openPath.isNotEmpty) {
      await openPdf(openPath);
    }

    return result;
  }

  /// Genera el documento PDF oficial de Factura Legal SET Paraguay
  static Future<Uint8List> generateLegalInvoicePdf({
    required Map<String, dynamic> invoice,
    Booking? booking,
    required String guestName,
    String? guestDoc,
    String? guestEmail,
  }) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat('#,##0', 'es_PY');

    final String numeroFactura = invoice['numero_factura']?.toString() ?? '001-001-0000123';
    final double montoTotal = (invoice['monto_total'] as num?)?.toDouble() ?? 72000.0;
    final double montoIva = (invoice['monto_iva'] as num?)?.toDouble() ?? (montoTotal / 11).roundToDouble();
    final double montoSubtotal = (invoice['monto_subtotal'] as num?)?.toDouble() ?? (montoTotal - montoIva);
    final String fechaStr = invoice['fecha_emision']?.toString() ?? invoice['created_at']?.toString() ?? DateTime.now().toIso8601String();
    final DateTime fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
    final String fechaFormatted = DateFormat('dd/MM/yyyy HH:mm').format(fecha);

    final String resCode = booking?.codigoReserva ?? (invoice['reserva_codigo']?.toString() ?? 'RES');
    final String concepto = invoice['concepto']?.toString() ??
        (montoTotal < (booking?.montoTotal ?? 999999999)
            ? 'Entrega / Seña por Reserva $resCode'
            : 'Liquidación Final Estadía $resCode');

    final String clientName = invoice['razon_social']?.toString() ?? guestName;
    final String clientDoc = invoice['ruc_ci']?.toString() ?? guestDoc ?? '44444401-7';

    final fontBold = pw.Font.helveticaBold();
    final fontSemiBold = pw.Font.helveticaBold();
    final fontRegular = pw.Font.helvetica();

    const navyColor = PdfColor.fromInt(0xFF0F172A);
    const goldColor = PdfColor.fromInt(0xFFC5A059);
    const slateColor = PdfColor.fromInt(0xFF64748B);
    const borderColor = PdfColor.fromInt(0xFFCBD5E1);
    const cardBgColor = PdfColor.fromInt(0xFFF8FAFC);
    const greenColor = PdfColor.fromInt(0xFF166534);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Barra Tricolor de la Bandera Paraguaya
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Container(height: 4, color: const PdfColor.fromInt(0xFFDC2626)),
                  ),
                  pw.Expanded(
                    child: pw.Container(height: 4, color: const PdfColor.fromInt(0xFFFFFFFF)),
                  ),
                  pw.Expanded(
                    child: pw.Container(height: 4, color: const PdfColor.fromInt(0xFF1E40AF)),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 2. Encabezado Institucional & Timbrado SET
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'HOTEL 3 VAGOS S.A.',
                        style: pw.TextStyle(font: fontBold, fontSize: 16, color: navyColor),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Servicios de Alojamiento y Hospedaje Turístico de Alta Gama',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: slateColor),
                      ),
                      pw.Text(
                        'Asunción, Paraguay • Convenio Académico e Institucional UTCD',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: slateColor),
                      ),
                      pw.Text(
                        'Tel: +595 21 555-0199 | E-mail: recepcion@hotel3vagos.com.py',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8, color: slateColor),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: cardBgColor,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: borderColor, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TIMBRADO SET: 16789423', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor)),
                        pw.Text('RUC: 80092341-2', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor)),
                        pw.Text('Válido hasta: 31/12/2026', style: pw.TextStyle(font: fontRegular, fontSize: 7.5, color: slateColor)),
                        pw.SizedBox(height: 3),
                        pw.Text('FACTURA LEGAL', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: goldColor)),
                        pw.Text('N° $numeroFactura', style: pw.TextStyle(font: fontBold, fontSize: 9.5, color: const PdfColor.fromInt(0xFF1E40AF))),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: borderColor, thickness: 0.8),
              pw.SizedBox(height: 10),

              // 3. Datos del Cliente / Receptor
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderColor, width: 0.6),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RAZÓN SOCIAL / NOMBRE:', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: slateColor)),
                          pw.SizedBox(height: 2),
                          pw.Text(clientName, style: pw.TextStyle(font: fontBold, fontSize: 10, color: navyColor)),
                          pw.SizedBox(height: 6),
                          pw.Text('RUC / CÉDULA DE IDENTIDAD:', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: slateColor)),
                          pw.SizedBox(height: 2),
                          pw.Text(clientDoc, style: pw.TextStyle(font: fontSemiBold, fontSize: 9, color: navyColor)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FECHA DE EMISIÓN:', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: slateColor)),
                          pw.SizedBox(height: 2),
                          pw.Text(fechaFormatted, style: pw.TextStyle(font: fontSemiBold, fontSize: 8.5, color: navyColor)),
                          pw.SizedBox(height: 6),
                          pw.Text('CONDICIÓN DE VENTA:', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: slateColor)),
                          pw.SizedBox(height: 2),
                          pw.Text('CONTADO (Digital / App Móvil)', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: greenColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 4. Tabla de Conceptos y Servicios
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: borderColor, width: 0.6),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  children: [
                    // Cabecera
                    pw.Container(
                      color: navyColor,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 32, child: pw.Text('CANT.', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white))),
                          pw.Expanded(flex: 4, child: pw.Text('DESCRIPCIÓN DEL CONCEPTO / SERVICIO', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white))),
                          pw.Expanded(flex: 2, child: pw.Text('PRECIO UNIT.', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white))),
                          pw.Expanded(flex: 2, child: pw.Text('GRAVADAS 10%', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: PdfColors.white))),
                        ],
                      ),
                    ),
                    // Fila única / concepto
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: pw.Row(
                        children: [
                          pw.SizedBox(width: 32, child: pw.Text('1', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: navyColor))),
                          pw.Expanded(
                            flex: 4,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(concepto, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor)),
                                if (booking != null)
                                  pw.Text(
                                    'Habitación ${booking.habitacionNumero} (${booking.habitacionTipo}) • Estadía ${booking.checkInPrevisto} al ${booking.checkOutPrevisto}',
                                    style: pw.TextStyle(font: fontRegular, fontSize: 7.2, color: slateColor),
                                  ),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('${currencyFormat.format(montoTotal)} Gs.', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: navyColor)),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('${currencyFormat.format(montoSubtotal)} Gs.', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: navyColor)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 5. Liquidación Impositiva SET (IVA 10%)
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: cardBgColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: borderColor, width: 0.6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('LIQUIDACIÓN DEL IVA (SET PARAGUAY):', style: pw.TextStyle(font: fontBold, fontSize: 7.5, color: slateColor)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Gravadas 10%: ${currencyFormat.format(montoSubtotal)} Gs.  |  IVA 10%: ${currencyFormat.format(montoIva)} Gs.  |  Exentas: 0 Gs.',
                          style: pw.TextStyle(font: fontSemiBold, fontSize: 7.5, color: navyColor),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFDCFCE7),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFFBBF7D0), width: 0.8),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Text('TOTAL LIQUIDADO: ', style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: greenColor)),
                          pw.Text('${currencyFormat.format(montoTotal)} Gs.', style: pw.TextStyle(font: fontBold, fontSize: 11, color: greenColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              // 6. Pie de Página Legal
              pw.Text(
                'Factura emitida conforme a las normativas del Ministerio de Economía y Finanzas / Dirección Nacional de Ingresos Tributarios (SET/DNIT). Documento con plena validez tributaria y legal.',
                style: pw.TextStyle(font: fontRegular, fontSize: 6.8, color: slateColor),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 0.6, color: borderColor),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma y Sello Administración Hotel 3 Vagos', style: pw.TextStyle(font: fontRegular, fontSize: 7, color: slateColor)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 0.6, color: borderColor),
                      pw.SizedBox(height: 4),
                      pw.Text('Firma de Conformidad Huésped', style: pw.TextStyle(font: fontRegular, fontSize: 7, color: slateColor)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Guarda la Factura Legal PDF en Descargas y la abre inmediatamente
  static Future<Map<String, dynamic>> saveAndOpenInvoicePdf({
    required Map<String, dynamic> invoice,
    Booking? booking,
    required String guestName,
    String? guestDoc,
    String? guestEmail,
  }) async {
    final pdfBytes = await generateLegalInvoicePdf(
      invoice: invoice,
      booking: booking,
      guestName: guestName,
      guestDoc: guestDoc,
      guestEmail: guestEmail,
    );

    final String numFact = invoice['numero_factura']?.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_') ?? 'FAC';
    final fileName = 'Factura_SET_$numFact.pdf';

    String? publicDownloadPath;
    String? appCachePath;

    if (Platform.isAndroid) {
      try {
        final publicDownloadDir = Directory('/storage/emulated/0/Download');
        if (publicDownloadDir.existsSync()) {
          final testFile = File('${publicDownloadDir.path}/$fileName');
          await testFile.writeAsBytes(pdfBytes, flush: true);
          publicDownloadPath = testFile.path;
        }
      } catch (_) {}
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/$fileName');
      await cacheFile.writeAsBytes(pdfBytes, flush: true);
      appCachePath = cacheFile.path;
    } catch (_) {
      final docDir = await getApplicationDocumentsDirectory();
      final docFile = File('${docDir.path}/$fileName');
      await docFile.writeAsBytes(pdfBytes, flush: true);
      appCachePath = docFile.path;
    }

    final safeCachePath = appCachePath;
    final finalPath = publicDownloadPath ?? safeCachePath;

    final result = {
      'path': finalPath,
      'cachePath': safeCachePath,
      'fileName': fileName,
      'bytes': pdfBytes,
    };

    final String openPath = (result['cachePath'] as String?)?.isNotEmpty == true
        ? result['cachePath'] as String
        : (result['path'] as String? ?? '');

    if (openPath.isNotEmpty) {
      await openPdf(openPath);
    }

    return result;
  }

  // --- Helpers de Renderizado de Tablas en PDF ---

  static pw.Widget _buildTableHeaderCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor textColor = const PdfColor.fromInt(0xFF0F172A),
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 7.5, color: textColor),
      ),
    );
  }

  static pw.Widget _buildTaxRow(
    String label,
    String value,
    pw.Font font, {
    PdfColor color = const PdfColor.fromInt(0xFF64748B),
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 7.5, color: color)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 7.5, color: color)),
        ],
      ),
    );
  }
}
