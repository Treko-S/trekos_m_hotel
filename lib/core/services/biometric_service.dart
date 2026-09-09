import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();
  static const String _prefKeyBiometric = 'biometric_auth_enabled';
  static const String _prefKeyLastActive = 'biometric_last_active_timestamp';

  /// Verifica si el hardware del dispositivo soporta biometría y si está configurada
  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      debugPrint('⚠️ [BiometricService] Error al verificar soporte biométrico: $e');
      return false;
    }
  }

  /// Retorna los tipos de biometría disponibles en el dispositivo
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('⚠️ [BiometricService] Error al obtener biometrías: $e');
      return [];
    }
  }

  /// Consulta si el usuario activó la huella dactilar en la app
  Future<bool> isBiometricEnabled() async {
    try {
      final val = await _storage.read(key: _prefKeyBiometric);
      return val == 'true';
    } catch (e) {
      debugPrint('⚠️ [BiometricService] Error al leer preferencia biométrica: $e');
      return false;
    }
  }

  /// Guarda la activación o desactivación de la huella dactilar
  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(key: _prefKeyBiometric, value: enabled ? 'true' : 'false');
      debugPrint('🔐 [BiometricService] Huella dactilar guardada: $enabled');
    } catch (e) {
      debugPrint('⚠️ [BiometricService] Error al guardar preferencia biométrica: $e');
    }
  }

  /// Ejecuta el prompt nativo de huella dactilar / biometría
  Future<bool> authenticate({
    String reason = 'Confirma tu huella digital para acceder de forma segura a Hotel 3Vagos',
  }) async {
    try {
      final available = await isBiometricAvailable();
      if (!available) {
        debugPrint('⚠️ [BiometricService] Biometría no disponible en este dispositivo');
        return false;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
      );

      if (didAuthenticate) {
        await updateLastActiveTimestamp();
      }

      return didAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [BiometricService] Excepción de plataforma al autenticar: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('⚠️ [BiometricService] Error inesperado durante autenticación biométrica: $e');
      return false;
    }
  }

  /// Registra la marca de tiempo de última actividad
  Future<void> updateLastActiveTimestamp() async {
    try {
      await _storage.write(
        key: _prefKeyLastActive,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {}
  }

  /// Determina si la sesión requiere re-autenticación biométrica tras inactividad
  /// (Estilo banca: más de 30 segundos en segundo plano o nueva sesión)
  Future<bool> shouldPromptBiometric({Duration timeout = const Duration(seconds: 30)}) async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) return false;

      final lastActiveRaw = await _storage.read(key: _prefKeyLastActive);
      if (lastActiveRaw == null || lastActiveRaw.isEmpty) return true;

      final lastActiveMillis = int.tryParse(lastActiveRaw);
      if (lastActiveMillis == null) return true;

      final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMillis);
      final difference = DateTime.now().difference(lastActive);

      return difference > timeout;
    } catch (_) {
      return false;
    }
  }
}
