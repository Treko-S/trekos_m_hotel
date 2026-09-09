import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // 'invoice' | 'booking' | 'cancel' | 'stay' | 'folio' | 'promo'
  final DateTime createdAt;
  bool isRead;
  final Map<String, dynamic>? data;

  StoredNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        'data': data,
      };

  factory StoredNotificationItem.fromJson(Map<String, dynamic> json) => StoredNotificationItem(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: (json['type'] as String?) ?? 'stay',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        isRead: json['is_read'] as bool? ?? false,
        data: json['data'] as Map<String, dynamic>?,
      );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKeyNotifs = 'stored_user_notifications_v1';

  bool _isInitialized = false;

  /// Notificador reactivo para actualizar la campanita en tiempo real
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Callback global para manejar clics en notificaciones
  Function(String? payload)? onNotificationClick;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (onNotificationClick != null) {
            onNotificationClick!(response.payload);
          }
        },
      );

      // Crear canales en Android con máxima prioridad
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        await androidImpl?.requestNotificationsPermission();

        const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
          'hotel_3vagos_channel',
          'Hotel 3Vagos - Alertas y Notificaciones',
          description: 'Canal oficial de recordatorios de estancia, facturas y promociones',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );

        const AndroidNotificationChannel invoiceChannel = AndroidNotificationChannel(
          'hotel_3vagos_invoices_channel',
          'Hotel 3Vagos - Facturas y Comprobantes Legales',
          description: 'Notificaciones inmediatas de facturas electrónicas SET y comprobantes',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );

        await androidImpl?.createNotificationChannel(generalChannel);
        await androidImpl?.createNotificationChannel(invoiceChannel);
      }

      await refreshUnreadCount();
      _isInitialized = true;
      debugPrint('🔔 [NotificationService] Inicializado exitosamente con canales de alta prioridad');
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error al inicializar notificaciones: $e');
    }
  }

  /// Consulta si la preferencia de alerta está activada por el usuario
  Future<bool> isPreferenceEnabled(String prefKey, {bool defaultValue = true}) async {
    try {
      final val = await _storage.read(key: prefKey);
      if (val == null) return defaultValue;
      return val == 'true';
    } catch (_) {
      return defaultValue;
    }
  }

  /// Muestra una notificación profesional en la barra de estado del sistema (Android Notification Shade)
  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String channelId = 'hotel_3vagos_channel',
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelId == 'hotel_3vagos_invoices_channel'
            ? 'Hotel 3Vagos - Facturas y Comprobantes Legales'
            : 'Hotel 3Vagos - Alertas y Notificaciones',
        channelDescription: 'Canal oficial de recordatorios de estancia, facturas y promociones',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        visibility: NotificationVisibility.public,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
      debugPrint('🔔 [NotificationService] Notificación en barra de estado emitida: $title');
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error al mostrar notificación del sistema: $e');
    }
  }

  /// Método de despacho unificado: evalúa la preferencia de alerta del usuario,
  /// emite la notificación en la barra del dispositivo y la guarda en la campanita.
  Future<bool> notifyUser({
    required String title,
    required String body,
    required String type, // 'invoice' | 'booking' | 'cancel' | 'stay' | 'folio' | 'promo'
    String? prefKey, // p.ej. 'alert_pref_invoice_app_mail', 'alert_pref_checkin', etc.
    bool defaultValue = true,
    Map<String, dynamic>? data,
  }) async {
    // 1. Verificar preferencia de alerta configurada
    if (prefKey != null) {
      final bool enabled = await isPreferenceEnabled(prefKey, defaultValue: defaultValue);
      if (!enabled) {
        debugPrint('🔕 [NotificationService] Notificación omitida por preferencia desactivada ($prefKey): $title');
        return false;
      }
    }

    // 2. Guardar en almacenamiento persistente de la campanita
    final String notifId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = StoredNotificationItem(
      id: notifId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
      data: data,
    );

    await _saveStoredNotification(newItem);

    // 3. Emitir en la barra de notificaciones del dispositivo celular / tablet
    final int notifNumId = DateTime.now().millisecondsSinceEpoch % 100000;
    final String channelId = (type == 'invoice')
        ? 'hotel_3vagos_invoices_channel'
        : 'hotel_3vagos_channel';

    final payload = jsonEncode({
      'id': notifId,
      'type': type,
      'data': data ?? {},
    });

    await showNotification(
      id: notifNumId,
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
    );

    await refreshUnreadCount();
    return true;
  }

  /// Obtiene la lista de notificaciones almacenadas localmente
  Future<List<StoredNotificationItem>> getStoredNotifications() async {
    try {
      final raw = await _storage.read(key: _storageKeyNotifs);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StoredNotificationItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error al leer notificaciones almacenadas: $e');
      return [];
    }
  }

  Future<void> _saveStoredNotification(StoredNotificationItem item) async {
    try {
      final currentList = await getStoredNotifications();
      // Evitar duplicados por id o título idéntico en menos de 2 minutos
      currentList.removeWhere((existing) =>
          existing.id == item.id ||
          (existing.title == item.title &&
              existing.createdAt.difference(item.createdAt).abs().inMinutes < 2));

      currentList.insert(0, item);
      // Limitar a las últimas 40 notificaciones
      final trimmed = currentList.take(40).map((e) => e.toJson()).toList();
      await _storage.write(key: _storageKeyNotifs, value: jsonEncode(trimmed));
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error al guardar notificación: $e');
    }
  }

  /// Marca una notificación como leída
  Future<void> markAsRead(String id) async {
    try {
      final list = await getStoredNotifications();
      for (var item in list) {
        if (item.id == id) {
          item.isRead = true;
          break;
        }
      }
      await _storage.write(
        key: _storageKeyNotifs,
        value: jsonEncode(list.map((e) => e.toJson()).toList()),
      );
      await refreshUnreadCount();
    } catch (_) {}
  }

  /// Marca todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    try {
      final list = await getStoredNotifications();
      for (var item in list) {
        item.isRead = true;
      }
      await _storage.write(
        key: _storageKeyNotifs,
        value: jsonEncode(list.map((e) => e.toJson()).toList()),
      );
      unreadCountNotifier.value = 0;
    } catch (_) {}
  }

  /// Refresca el conteo de notificaciones no leídas para el badge de la campanita
  Future<int> refreshUnreadCount() async {
    try {
      final list = await getStoredNotifications();
      final unread = list.where((n) => !n.isRead).length;
      unreadCountNotifier.value = unread;
      return unread;
    } catch (_) {
      return 0;
    }
  }
}
