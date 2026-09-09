import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trekos_m_hotel/core/services/notification_service.dart';
import 'package:trekos_m_hotel/core/services/biometric_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('NotificationService Tests', () {
    test('Valida y respeta las preferencias del usuario para cada canal', () async {
      final notifService = NotificationService();

      // Por defecto facturas y check-in están habilitadas (true)
      final invoiceEnabled = await notifService.isPreferenceEnabled('alert_pref_invoice_app_mail');
      expect(invoiceEnabled, isTrue);

      final checkinEnabled = await notifService.isPreferenceEnabled('alert_pref_checkin');
      expect(checkinEnabled, isTrue);

      // Desactivamos la preferencia de promociones en el almacenamiento seguro
      const storage = FlutterSecureStorage();
      await storage.write(key: 'alert_pref_promo', value: 'false');

      final promoEnabled = await notifService.isPreferenceEnabled('alert_pref_promo');
      expect(promoEnabled, isFalse);

      // Si intentamos notificar con una preferencia desactivada, notifyUser retorna false
      final notified = await notifService.notifyUser(
        title: 'Descuento especial UTCD',
        body: 'Aprovecha 20% off en tu próxima reserva.',
        type: 'promo',
        prefKey: 'alert_pref_promo',
      );
      expect(notified, isFalse);
    });

    test('notifyUser persiste notificaciones en storage y actualiza unreadCountNotifier', () async {
      final notifService = NotificationService();

      final result1 = await notifService.notifyUser(
        title: 'Factura Electrónica Emitida',
        body: 'Tu factura Nº 001-002-0004512 está disponible.',
        type: 'invoice',
        prefKey: 'alert_pref_invoice_app_mail',
        data: {'invoice_url': 'https://hotel3vagos.com/factura/4512.pdf'},
      );
      expect(result1, isTrue);

      final storedList = await notifService.getStoredNotifications();
      expect(storedList.length, equals(1));
      expect(storedList.first.title, equals('Factura Electrónica Emitida'));
      expect(storedList.first.type, equals('invoice'));
      expect(storedList.first.isRead, isFalse);
      expect(notifService.unreadCountNotifier.value, equals(1));

      // Añadir una segunda notificación de comprobante de reserva
      final result2 = await notifService.notifyUser(
        title: '¡Reserva Confirmada! Habitación 101',
        body: 'Tu reserva fue procesada con éxito.',
        type: 'booking',
      );
      expect(result2, isTrue);

      final updatedList = await notifService.getStoredNotifications();
      expect(updatedList.length, equals(2));
      expect(notifService.unreadCountNotifier.value, equals(2));

      // Marcar la primera como leída
      final firstId = updatedList.first.id;
      await notifService.markAsRead(firstId);
      expect(notifService.unreadCountNotifier.value, equals(1));

      // Marcar todas como leídas
      await notifService.markAllAsRead();
      expect(notifService.unreadCountNotifier.value, equals(0));
    });
  });

  group('BiometricService Tests', () {
    test('Estado inicial y persistencia del switch de huella dactilar', () async {
      final bioService = BiometricService();

      // Por defecto desactivado
      final initialStatus = await bioService.isBiometricEnabled();
      expect(initialStatus, isFalse);

      // Habilitar
      await bioService.setBiometricEnabled(true);
      final updatedStatus = await bioService.isBiometricEnabled();
      expect(updatedStatus, isTrue);

      // Deshabilitar
      await bioService.setBiometricEnabled(false);
      expect(await bioService.isBiometricEnabled(), isFalse);
    });

    test('Control de re-autenticación por inactividad de sesión estilo bancario', () async {
      final bioService = BiometricService();

      // Cuando la biometría no está habilitada, shouldPromptBiometric siempre retorna false
      await bioService.setBiometricEnabled(false);
      expect(await bioService.shouldPromptBiometric(), isFalse);

      // Si se activa la biometría y no hay timestamp previo, debe requerir prompt
      await bioService.setBiometricEnabled(true);
      expect(await bioService.shouldPromptBiometric(), isTrue);

      // Actualizamos la marca de actividad reciente
      await bioService.updateLastActiveTimestamp();
      // Con actividad reciente y timeout de 30 segundos, no debe pedir biometría
      expect(await bioService.shouldPromptBiometric(timeout: const Duration(seconds: 30)), isFalse);

      // Con timeout de 0 milisegundos, simula sesión expirada y debe pedir biometría
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(await bioService.shouldPromptBiometric(timeout: const Duration(milliseconds: 5)), isTrue);
    });
  });
}
