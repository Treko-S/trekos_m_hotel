import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:trekos_m_hotel/core/services/hotel_settings_service.dart';

class EmailNotificationService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static String get _brevoApiKey =>
      dotenv.env['BREVO_API_KEY']?.trim() ?? '';
  static String get _brevoSenderEmail =>
      dotenv.env['BREVO_SENDER_EMAIL']?.trim() ?? 'mckakucorpii@gmail.com';
  static String get _brevoSenderName =>
      dotenv.env['BREVO_SENDER_NAME']?.trim() ?? 'Hotel 3 Vagos';

  static String _formatGs(double amount) {
    final formatter = NumberFormat('#,###', 'es_PY');
    return '${formatter.format(amount.round()).replaceAll(',', '.')} Gs.';
  }

  /// Envía un correo con la confirmación oficial de reserva y folio de cuenta
  static Future<bool> sendBookingConfirmation({
    required String recipientEmail,
    required String guestName,
    required String bookingCode,
    required String roomNumber,
    required String roomType,
    required DateTime checkIn,
    required DateTime checkOut,
    required double totalAmount,
    double paidAmount = 0.0,
  }) async {
    final remaining = (totalAmount - paidAmount).clamp(0.0, double.infinity);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final iva10 = (totalAmount / 11).round();
    final gravada10 = (totalAmount / 1.10).round();

    final htmlBody = '''
      <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); color: #ffffff; padding: 26px 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #D4AF37; letter-spacing: 1px;">HOTEL 3 VAGOS</h1>
          <p style="margin: 4px 0 0; font-size: 12px; color: #94A3B8;">Hospitalidad & Excelencia - UTCD Asunción</p>
        </div>

        <div style="padding: 24px;">
          <div style="background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 12px 16px; margin-bottom: 20px;">
            <div style="font-size: 11px; color: #64748B;">RUC: <strong>80092341-2</strong> | Timbrado SET: <strong>16789423</strong> (Vig. 31/12/2026)</div>
            <div style="font-size: 13px; font-weight: 700; color: #0F172A; margin-top: 2px;">
              CONFIRMACIÓN OFICIAL DE RESERVA & FOLIO
            </div>
          </div>

          <p style="font-size: 14px; color: #334155; margin-bottom: 16px;">
            Estimado/a <strong>$guestName</strong>,<br>
            ¡Tu reserva ha sido confirmada con éxito! A continuación te presentamos el resumen de tu folio:
          </p>

          <table style="width: 100%; font-size: 13px; border-collapse: collapse; margin-bottom: 20px;">
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Código de Reserva:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 700; color: #0F172A;">$bookingCode</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Habitación:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 600;">Habitación $roomNumber ($roomType)</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Check-in:</td>
              <td style="padding: 8px 0; text-align: right;">${dateFmt.format(checkIn)} (${HotelSettingsService.checkInTime} Hs)</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Check-out:</td>
              <td style="padding: 8px 0; text-align: right;">${dateFmt.format(checkOut)} (${HotelSettingsService.checkOutTime} Hs)</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Monto Total Estadía:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 700;">${_formatGs(totalAmount)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0; background: #F0FDF4;">
              <td style="padding: 8px 6px; color: #166534; font-weight: 600;">Seña / Pago Registrado:</td>
              <td style="padding: 8px 6px; text-align: right; font-weight: 700; color: #15803D;">-${_formatGs(paidAmount)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B; font-weight: 700;">Saldo a Liquidar:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 800; color: ${remaining > 0 ? '#DC2626' : '#15803D'}; font-size: 15px;">
                ${_formatGs(remaining)}
              </td>
            </tr>
          </table>

          <div style="background: #F8FAFC; border-radius: 8px; padding: 12px; font-size: 11.5px; color: #64748B; margin-bottom: 20px;">
            <strong>Liquidación Impositiva SET (Paraguay):</strong> Gravadas 10%: ${_formatGs(gravada10.toDouble())} | Liquidación IVA 10%: ${_formatGs(iva10.toDouble())} | Exentas: 0 Gs.
          </div>

          <div style="text-align: center; color: #94A3B8; font-size: 12px; line-height: 1.5;">
            <p style="margin: 0 0 4px;">Hotel 3 Vagos - Asunción, Paraguay</p>
            <p style="margin: 0; font-size: 11px;">Recepción y Asistencia 24/7 disponible en el hotel o vía WhatsApp.</p>
          </div>
        </div>
      </div>
    ''';

    return _dispatchEmail(
      recipientEmail: recipientEmail,
      guestName: guestName,
      subject: 'Confirmación de Reserva $bookingCode | Hotel 3 Vagos',
      htmlContent: htmlBody,
    );
  }

  /// Envía un comprobante digital de pago / seña registrada
  static Future<bool> sendPaymentReceipt({
    required String recipientEmail,
    required String guestName,
    required String bookingCode,
    required String roomNumber,
    required double totalAmount,
    required double paidAmount,
    required double remainingAmount,
    required String paymentMethod,
    required String transactionRef,
  }) async {
    final iva10 = (totalAmount / 11).round();
    final gravada10 = (totalAmount / 1.10).round();
    final nowFmt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final htmlBody = '''
      <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); color: #ffffff; padding: 26px 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #D4AF37; letter-spacing: 1px;">HOTEL 3 VAGOS</h1>
          <p style="margin: 4px 0 0; font-size: 12px; color: #94A3B8;">Hospitalidad & Excelencia - UTCD Asunción</p>
        </div>

        <div style="padding: 24px;">
          <div style="background: #F0FDF4; border: 1px solid #BBF7D0; border-radius: 8px; padding: 12px 16px; margin-bottom: 20px;">
            <div style="font-size: 11px; color: #166534;">RUC: <strong>80092341-2</strong> | Timbrado SET: <strong>16789423</strong></div>
            <div style="font-size: 14px; font-weight: 700; color: #15803D; margin-top: 2px;">
              ✓ COMPROBANTE OFICIAL DE ABONO / SEÑA REGISTRADA
            </div>
          </div>

          <p style="font-size: 14px; color: #334155; margin-bottom: 16px;">
            Hola <strong>$guestName</strong>,<br>
            Tu pago ha sido procesado y acreditado a tu folio de cuenta. Aquí tienes los detalles:
          </p>

          <table style="width: 100%; font-size: 13px; border-collapse: collapse; margin-bottom: 20px;">
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">N° Operación / Referencia:</td>
              <td style="padding: 8px 0; text-align: right; font-family: monospace; font-weight: 700; color: #0F172A;">$transactionRef</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Fecha y Hora:</td>
              <td style="padding: 8px 0; text-align: right;">$nowFmt</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Código de Reserva:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 600;">$bookingCode (Hab. $roomNumber)</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Método de Pago:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 600;">$paymentMethod</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0; background: #F0FDF4;">
              <td style="padding: 8px 6px; color: #166534; font-weight: 700;">Monto Abonado:</td>
              <td style="padding: 8px 6px; text-align: right; font-weight: 800; color: #15803D; font-size: 15px;">${_formatGs(paidAmount)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B;">Total de Alojamiento:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 600;">${_formatGs(totalAmount)}</td>
            </tr>
            <tr style="border-bottom: 1px solid #E2E8F0;">
              <td style="padding: 8px 0; color: #64748B; font-weight: 700;">Saldo Pendiente Actual:</td>
              <td style="padding: 8px 0; text-align: right; font-weight: 800; color: ${remainingAmount > 0 ? '#DC2626' : '#15803D'}; font-size: 15px;">
                ${_formatGs(remainingAmount)}
              </td>
            </tr>
          </table>

          <div style="background: #F8FAFC; border-radius: 8px; padding: 12px; font-size: 11.5px; color: #64748B; margin-bottom: 20px;">
            <strong>Desglose Impositivo SET Paraguay:</strong> Gravadas 10%: ${_formatGs(gravada10.toDouble())} | IVA 10%: ${_formatGs(iva10.toDouble())} | Exentas: 0 Gs.
          </div>

          <div style="text-align: center; color: #94A3B8; font-size: 12px; line-height: 1.5;">
            <p style="margin: 0 0 4px;">Hotel 3 Vagos S.A. - RUC: 80092341-2</p>
            <p style="margin: 0; font-size: 11px;">Podrás consultar y descargar tu folio digital en cualquier momento desde la App.</p>
          </div>
        </div>
      </div>
    ''';

    return _dispatchEmail(
      recipientEmail: recipientEmail,
      guestName: guestName,
      subject: 'Recibo de Pago $transactionRef - Reserva $bookingCode | Hotel 3 Vagos',
      htmlContent: htmlBody,
    );
  }

  static Future<bool> _dispatchEmail({
    required String recipientEmail,
    required String guestName,
    required String subject,
    required String htmlContent,
  }) async {
    final to = recipientEmail.trim();
    if (to.isEmpty) return false;

    // Registrar o sincronizar automáticamente el contacto en Brevo
    syncContactWithBrevo(email: to, name: guestName);

    return _sendViaBrevo(
      recipientEmail: to,
      guestName: guestName,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  static Future<bool> _sendViaBrevo({
    required String recipientEmail,
    required String guestName,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      final toName = guestName.trim().isNotEmpty ? guestName.trim() : 'Huésped';

      final response = await _dio.post(
        'https://api.brevo.com/v3/smtp/email',
        options: Options(
          headers: {
            'api-key': _brevoApiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
        data: {
          'sender': {
            'name': _brevoSenderName,
            'email': _brevoSenderEmail,
          },
          'to': [
            {
              'email': recipientEmail,
              'name': toName,
            }
          ],
          'subject': subject,
          'htmlContent': htmlContent,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Email entregado exitosamente a $recipientEmail vía Brevo API');
        return true;
      }

      debugPrint('Brevo API status ${response.statusCode}: ${response.data}');
      return false;
    } catch (e) {
      debugPrint('Error en Brevo API dispatch: $e');
      return false;
    }
  }

  /// Registra o sincroniza un nuevo huésped en la libreta de contactos oficial de Brevo
  static Future<bool> syncContactWithBrevo({
    required String email,
    String? name,
    String? phone,
  }) async {
    try {
      final cleanEmail = email.trim();
      if (cleanEmail.isEmpty) return false;

      final nameParts = (name ?? '').trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final response = await _dio.post(
        'https://api.brevo.com/v3/contacts',
        options: Options(
          headers: {
            'api-key': _brevoApiKey,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => true,
        ),
        data: {
          'email': cleanEmail,
          'attributes': {
            if (firstName.isNotEmpty) 'FIRSTNAME': firstName,
            if (lastName.isNotEmpty) 'LASTNAME': lastName,
            if (phone != null && phone.trim().isNotEmpty) 'SMS': phone.trim(),
          },
          'updateEnabled': true,
        },
      );

      if (response.statusCode == 201 ||
          response.statusCode == 204 ||
          response.statusCode == 200) {
        debugPrint('Huésped $cleanEmail sincronizado exitosamente en contactos de Brevo');
        return true;
      }
      debugPrint('Brevo contacts sync status ${response.statusCode}: ${response.data}');
      return false;
    } catch (e) {
      debugPrint('Error al sincronizar contacto con Brevo: $e');
      return false;
    }
  }

  /// Envía un correo oficial de bienvenida al nuevo usuario registrado en Hotel 3 Vagos
  static Future<bool> sendWelcomeEmail({
    required String recipientEmail,
    required String guestName,
  }) async {
    final cleanName = guestName.trim().isNotEmpty ? guestName.trim() : 'Huésped';

    final htmlBody = '''
      <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); color: #ffffff; padding: 28px 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #D4AF37; letter-spacing: 1px;">HOTEL 3 VAGOS</h1>
          <p style="margin: 4px 0 0; font-size: 12px; color: #94A3B8;">Hospitalidad & Excelencia - UTCD Asunción</p>
        </div>

        <div style="padding: 24px;">
          <div style="background: #F0FDF4; border: 1px solid #BBF7D0; border-radius: 8px; padding: 12px 16px; margin-bottom: 20px;">
            <div style="font-size: 14px; font-weight: 700; color: #15803D;">
              ✓ ¡BIENVENIDO/A A HOTEL 3 VAGOS!
            </div>
            <div style="font-size: 11px; color: #166534; margin-top: 2px;">
              Tu cuenta ha sido creada exitosamente en nuestra plataforma oficial.
            </div>
          </div>

          <p style="font-size: 14px; color: #334155; margin-bottom: 16px;">
            Estimado/a <strong>$cleanName</strong>,<br>
            Nos complace darte la más cordial bienvenida a Hotel 3 Vagos. A partir de ahora podrás explorar nuestras habitaciones de lujo, realizar reservas instantáneas con confirmación inmediata y gestionar tus folios y comprobantes legales SET (RUC 80092341-2) en todo momento.
          </p>

          <div style="background: #F8FAFC; border-radius: 8px; padding: 16px; margin-bottom: 20px; border: 1px solid #E2E8F0;">
            <h4 style="margin: 0 0 8px; font-size: 13px; color: #0F172A;">¿Qué puedes hacer desde la app?</h4>
            <ul style="margin: 0; padding-left: 18px; font-size: 12.5px; color: #475569; line-height: 1.6;">
              <li>Reservar habitaciones simples, dobles o suites premium.</li>
              <li>Abonar señas o liquidar estadías vía Transferencia SIPAP, Tarjeta o Billetera Móvil.</li>
              <li>Recibir facturas legales SET y comprobantes de abono directamente en tu correo.</li>
              <li>Consultar consumos de frigobar y cargos de cuenta en tiempo real.</li>
            </ul>
          </div>

          <div style="text-align: center; color: #94A3B8; font-size: 12px; line-height: 1.5;">
            <p style="margin: 0 0 4px;">Hotel 3 Vagos S.A. - Asunción, Paraguay</p>
            <p style="margin: 0; font-size: 11px;">Recepción y Asistencia 24/7 disponible para ti.</p>
          </div>
        </div>
      </div>
    ''';

    return _dispatchEmail(
      recipientEmail: recipientEmail,
      guestName: cleanName,
      subject: '¡Bienvenido/a a Hotel 3 Vagos, $cleanName! | Cuenta Creada',
      htmlContent: htmlBody,
    );
  }

  /// Envía un correo oficial notificando la cancelación de la reserva y la liquidación de reembolso / penalidad
  static Future<bool> sendCancellationEmail({
    required String recipientEmail,
    required String guestName,
    required String bookingCode,
    required String roomNumber,
    required String roomType,
    required String reason,
    required double totalAmount,
    required double paidAmount,
    required double refundAmount,
    required double penaltyAmount,
    required bool canFreeCancel,
  }) async {
    final cleanName = guestName.trim().isNotEmpty ? guestName.trim() : 'Huésped';

    final htmlBody = '''
      <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;">
        <div style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); color: #ffffff; padding: 26px 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 22px; font-weight: 700; color: #D4AF37; letter-spacing: 1px;">HOTEL 3 VAGOS</h1>
          <p style="margin: 4px 0 0; font-size: 12px; color: #94A3B8;">Hospitalidad & Excelencia - UTCD Asunción</p>
        </div>

        <div style="padding: 24px;">
          <div style="background: #FEF2F2; border: 1px solid #FECACA; border-radius: 8px; padding: 12px 16px; margin-bottom: 20px;">
            <div style="font-size: 11px; color: #991B1B;">RUC: <strong>80092341-2</strong> | Timbrado SET: <strong>16789423</strong></div>
            <div style="font-size: 14px; font-weight: 700; color: #DC2626; margin-top: 2px;">
              NOTIFICACIÓN OFICIAL DE CANCELACIÓN & LIQUIDACIÓN
            </div>
          </div>

          <p style="font-size: 14px; color: #334155; margin-bottom: 16px;">
            Estimado/a <strong>$cleanName</strong>,<br>
            Te informamos que tu reserva <strong>#$bookingCode</strong> correspondiente a la Habitación $roomNumber ($roomType) ha sido cancelada.
          </p>

          <div style="background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 12px; margin-bottom: 16px; font-size: 13px;">
            <strong style="color: #64748B;">Motivo Registrado:</strong><br>
            <span style="color: #0F172A; font-weight: 600;">$reason</span>
          </div>

          <div style="background: ${canFreeCancel ? '#F0FDF4' : '#FFFBEB'}; border: 1px solid ${canFreeCancel ? '#BBF7D0' : '#FDE68A'}; border-radius: 8px; padding: 14px; margin-bottom: 20px;">
            <div style="font-size: 13px; font-weight: 700; color: ${canFreeCancel ? '#166534' : '#92400E'}; margin-bottom: 8px;">
              ${canFreeCancel ? '✓ Reembolso Autorizado del 100%' : '⚠️ Política de Penalidad Aplicada'}
            </div>
            <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
              <tr>
                <td style="padding: 4px 0; color: #64748B;">Monto Adelantado / Pagado:</td>
                <td style="padding: 4px 0; text-align: right; font-weight: 600;">${_formatGs(paidAmount)}</td>
              </tr>
              <tr>
                <td style="padding: 4px 0; color: #64748B;">Penalidad Retenida:</td>
                <td style="padding: 4px 0; text-align: right; font-weight: 700; color: #DC2626;">-${_formatGs(penaltyAmount)}</td>
              </tr>
              <tr style="border-top: 1px solid #E2E8F0;">
                <td style="padding: 6px 0; font-weight: 700; color: #0F172A;">Monto a Reembolsar:</td>
                <td style="padding: 6px 0; text-align: right; font-weight: 800; color: #15803D; font-size: 15px;">${_formatGs(refundAmount)}</td>
              </tr>
            </table>
          </div>

          <div style="text-align: center; color: #94A3B8; font-size: 12px; line-height: 1.5;">
            <p style="margin: 0 0 4px;">Hotel 3 Vagos S.A. - Asunción, Paraguay</p>
            <p style="margin: 0; font-size: 11px;">Recepción y Asistencia 24/7 disponible para ti.</p>
          </div>
        </div>
      </div>
    ''';

    return _dispatchEmail(
      recipientEmail: recipientEmail,
      guestName: cleanName,
      subject: 'Cancelación de Reserva $bookingCode y Liquidación de Reembolso | Hotel 3 Vagos',
      htmlContent: htmlBody,
    );
  }
}
