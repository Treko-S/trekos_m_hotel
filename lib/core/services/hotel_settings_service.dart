import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio Central de Configuración Maestra del Hotel (Tarea 16)
/// Sincroniza dinámicamente horas de check-in, check-out, políticas legales
/// y paquetes promocionales para eliminar valores hardcodeados en la App Móvil.
class HotelSettingsService {
  static String hotelName = 'Hotel 3 Vagos';
  static String commercialName = 'Hospitality UTCD';
  static String ruc = '80092341-2';
  static String address = 'Avda. Santa Teresa c/ Aviadores del Chaco, Asunción, Paraguay';
  static String phone = '+595 21 600 000';
  static String whatsapp = '+595 981 123 456';
  static String email = 'reservas@hotel3vagos.com.py';
  static String currency = 'Gs.';
  static String timezone = 'America/Asuncion';
  static String checkInTime = '14:00';
  static String checkOutTime = '11:00';
  static String cancellationPolicyText =
      'Cancelación 100% gratuita hasta 24 hs previas al check-in en Tarifa Flexible. Tarifa Promo no admite reembolso.';
  static String termsAndConditionsText =
      'Prohibido fumar en todas las habitaciones y áreas cerradas. Horario de descanso y silencio de 22:00 a 08:00 hs. Presentar cédula de identidad o pasaporte original al ingresar.';
  static String logoUrl =
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800';
  static double taxVatRate = 10.0;

  static bool _isLoaded = false;
  static bool get isLoaded => _isLoaded;

  /// Inicializa la configuración descargándola de Supabase DB o Supabase Storage
  static Future<void> init() async {
    try {
      final client = Supabase.instance.client;

      // 1. Intentar cargar desde la tabla singleton `hotel_settings`
      try {
        final data = await client
            .from('hotel_settings')
            .select()
            .eq('id', 1)
            .maybeSingle();

        if (data != null) {
          _applySettingsMap(data);
          _isLoaded = true;
          debugPrint('HotelSettingsService: Sincronizado exitosamente desde DB.');
          return;
        }
      } catch (dbErr) {
        debugPrint('HotelSettingsService: DB no disponible, probando Storage: $dbErr');
      }

      // 2. Intentar cargar desde Supabase Storage: hotel-rooms/config/hotel_settings.json
      try {
        final bytes = await client.storage
            .from('hotel-rooms')
            .download('config/hotel_settings.json');

        final content = utf8.decode(bytes);
        final Map<String, dynamic> jsonMap = json.decode(content);
        _applySettingsMap(jsonMap);
        _isLoaded = true;
        debugPrint('HotelSettingsService: Sincronizado exitosamente desde Storage.');
        return;
      } catch (stErr) {
        debugPrint('HotelSettingsService: Storage no disponible: $stErr');
      }
    } catch (e) {
      debugPrint('HotelSettingsService.init error general: $e');
    }
  }

  static void _applySettingsMap(Map<String, dynamic> map) {
    if (map['hotel_name'] != null) hotelName = map['hotel_name'].toString();
    if (map['commercial_name'] != null) commercialName = map['commercial_name'].toString();
    if (map['ruc'] != null) ruc = map['ruc'].toString();
    if (map['address'] != null) address = map['address'].toString();
    if (map['phone'] != null) phone = map['phone'].toString();
    if (map['whatsapp'] != null) whatsapp = map['whatsapp'].toString();
    if (map['email'] != null) email = map['email'].toString();
    if (map['currency'] != null) currency = map['currency'].toString();
    if (map['timezone'] != null) timezone = map['timezone'].toString();

    if (map['check_in_time'] != null) {
      final raw = map['check_in_time'].toString();
      checkInTime = raw.length >= 5 ? raw.substring(0, 5) : raw;
    }
    if (map['check_out_time'] != null) {
      final raw = map['check_out_time'].toString();
      checkOutTime = raw.length >= 5 ? raw.substring(0, 5) : raw;
    }

    if (map['cancellation_policy_text'] != null) {
      cancellationPolicyText = map['cancellation_policy_text'].toString();
    }
    if (map['terms_and_conditions_text'] != null) {
      termsAndConditionsText = map['terms_and_conditions_text'].toString();
    }
    if (map['logo_url'] != null) logoUrl = map['logo_url'].toString();
    if (map['tax_vat_rate'] != null) {
      taxVatRate = (map['tax_vat_rate'] as num).toDouble();
    }
  }

  /// Consulta paquetes de promoción activos para un tipo de habitación dado (Tarea 13)
  static Future<List<Map<String, dynamic>>> getActivePromotionalPackages({int? roomTypeId}) async {
    try {
      final client = Supabase.instance.client;

      // 1. Intentar desde tabla `promotional_packages`
      try {
        var query = client
            .from('promotional_packages')
            .select('*, package_included_services(*)')
            .eq('is_active', true);

        final data = await query;
        if (data.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(data);
          if (roomTypeId != null) {
            final filtered = list.where((p) {
              final rId = p['room_type_id'];
              return rId == null || rId == roomTypeId;
            }).toList();
            if (filtered.isNotEmpty) return filtered;
          }
          return list;
        }
      } catch (dbEx) {
        debugPrint('getActivePromotionalPackages DB error: $dbEx');
      }

      // 2. Intentar desde Supabase Storage `hotel-rooms/config/promotional_packages.json`
      try {
        final bytes = await client.storage
            .from('hotel-rooms')
            .download('config/promotional_packages.json');
        final content = utf8.decode(bytes);
        final List<dynamic> jsonList = json.decode(content);
        final list = jsonList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((p) => p['is_active'] != false)
            .toList();

        if (roomTypeId != null) {
          final filtered = list.where((p) {
            final rId = p['room_type_id'];
            return rId == null || rId == roomTypeId;
          }).toList();
          if (filtered.isNotEmpty) return filtered;
        }
        return list;
      } catch (stEx) {
        debugPrint('getActivePromotionalPackages Storage error: $stEx');
      }
    } catch (e) {
      debugPrint('getActivePromotionalPackages error general: $e');
    }

    // 3. Fallback de cortesía garantizado
    return [
      {
        'id': 'pkg-romantico-vip',
        'name': 'Paquete Romántico VIP & Espumante',
        'description':
            'Champagne Moët frío en la habitación, bombones de autor, circuito spa relax y late check-out extendido.',
        'package_price': 520000,
        'image_url':
            'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
        'is_active': true,
        'services': [
          {'catalog_item_id': 1, 'item_name': 'Desayuno Buffet Premium', 'quantity': 2},
          {'catalog_item_id': 2, 'item_name': 'Circuito Spa & Sauna Relax', 'quantity': 2},
          {'catalog_item_id': 4, 'item_name': 'Champagne Moët / Vino Espumante', 'quantity': 1}
        ]
      }
    ];
  }
}
