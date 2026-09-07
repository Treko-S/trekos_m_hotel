import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

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

      // Solicitar permisos en Android 13+
      if (!kIsWeb && Platform.isAndroid) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('🔔 [NotificationService] Inicializado exitosamente');
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error al inicializar notificaciones: $e');
    }
  }

  /// Muestra una notificación profesional en la barra de estado del sistema (Android Notification Shade)
  Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'hotel_3vagos_channel',
        'Hotel 3Vagos - Alertas y Notificaciones',
        channelDescription: 'Canal oficial de recordatorios de estancia, facturas y promociones',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
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
      debugPrint('🔔 [NotificationService] Notificación emitida: $title');
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error al mostrar notificación del sistema: $e');
    }
  }
}
