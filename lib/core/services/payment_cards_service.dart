import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Modelo de tarjeta de pago guardada y sincronizada en Trekos M Hotel.
class SavedPaymentCard {
  final String id;
  final String cardholderName;
  final String cardNumber; // Número completo (16 dígitos con o sin espacios)
  final String expiry; // MM/AA
  final String cvv; // 3 o 4 dígitos
  final String type; // "Crédito" | "Débito"
  final String brand; // "Visa" | "Mastercard" | "American Express"
  bool isDefault;

  SavedPaymentCard({
    required this.id,
    required this.cardholderName,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.type,
    required this.brand,
    this.isDefault = false,
  });

  /// Retorna los últimos 4 dígitos de la tarjeta
  String get last4 {
    final clean = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 4) {
      return clean.substring(clean.length - 4);
    }
    return clean.isNotEmpty ? clean : '4242';
  }

  /// Retorna el número de tarjeta enmascarado para visualización segura
  String get maskedNumber {
    return '•••• •••• •••• $last4';
  }

  /// Retorna el número formateado con espacios cada 4 dígitos
  String get formattedNumber {
    final clean = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 16) {
      return cardNumber;
    }
    return '${clean.substring(0, 4)} ${clean.substring(4, 8)} ${clean.substring(8, 12)} ${clean.substring(12, 16)}';
  }

  bool get isVisa => brand.toLowerCase().contains('visa');
  bool get isMastercard => brand.toLowerCase().contains('mastercard');

  SavedPaymentCard copyWith({
    String? id,
    String? cardholderName,
    String? cardNumber,
    String? expiry,
    String? cvv,
    String? type,
    String? brand,
    bool? isDefault,
  }) {
    return SavedPaymentCard(
      id: id ?? this.id,
      cardholderName: cardholderName ?? this.cardholderName,
      cardNumber: cardNumber ?? this.cardNumber,
      expiry: expiry ?? this.expiry,
      cvv: cvv ?? this.cvv,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cardholderName': cardholderName,
      'cardNumber': cardNumber,
      'expiry': expiry,
      'cvv': cvv,
      'type': type,
      'brand': brand,
      'isDefault': isDefault,
    };
  }

  factory SavedPaymentCard.fromJson(Map<String, dynamic> json) {
    return SavedPaymentCard(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      cardholderName: json['cardholderName'] as String? ?? 'HUÉSPED TITULAR',
      cardNumber: json['cardNumber'] as String? ?? '4532890123454242',
      expiry: json['expiry'] as String? ?? '08/29',
      cvv: json['cvv'] as String? ?? '456',
      type: json['type'] as String? ?? 'Crédito',
      brand: json['brand'] as String? ?? 'Visa',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// Servicio centralizado para gestionar las tarjetas de pago sincronizadas
/// con almacenamiento persistente seguro mediante [FlutterSecureStorage].
class PaymentCardsService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'trekos_synced_payment_cards_v1';

  /// Genera las tarjetas añadidas por defecto (Crédito y Débito)
  static List<SavedPaymentCard> getDefaultCards({String? defaultOwnerName}) {
    final owner = (defaultOwnerName != null && defaultOwnerName.trim().isNotEmpty)
        ? defaultOwnerName.trim().toUpperCase()
        : 'KEVIN SANTACRUZ';

    return [
      SavedPaymentCard(
        id: 'default_card_credit_visa',
        cardholderName: owner,
        cardNumber: '4532 8901 2345 4242',
        expiry: '08/29',
        cvv: '456',
        type: 'Crédito',
        brand: 'Visa',
        isDefault: true,
      ),
      SavedPaymentCard(
        id: 'default_card_debit_mastercard',
        cardholderName: owner,
        cardNumber: '5412 7512 3412 8812',
        expiry: '11/27',
        cvv: '891',
        type: 'Débito',
        brand: 'Mastercard',
        isDefault: false,
      ),
    ];
  }

  /// Obtiene la lista completa de tarjetas guardadas y sincronizadas.
  /// Si no hay tarjetas guardadas en el almacenamiento seguro, se inicializan
  /// las tarjetas por defecto (Visa Crédito y Mastercard Débito).
  static Future<List<SavedPaymentCard>> getCards({String? defaultOwnerName}) async {
    try {
      final rawJson = await _storage.read(key: _storageKey);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        final cards = decoded
            .map((item) => SavedPaymentCard.fromJson(item as Map<String, dynamic>))
            .toList();

        if (cards.isNotEmpty) {
          // Aseguramos que al menos una esté marcada como predeterminada
          final hasDefault = cards.any((c) => c.isDefault);
          if (!hasDefault) {
            cards.first.isDefault = true;
          }
          return cards;
        }
      }
    } catch (_) {
      // Si ocurre un error al leer de secure storage, se recurre a las tarjetas por defecto
    }

    // Inicializar y persistir tarjetas por defecto
    final initialCards = getDefaultCards(defaultOwnerName: defaultOwnerName);
    await saveCards(initialCards);
    return initialCards;
  }

  /// Retorna la tarjeta predeterminada para autocarga en Folio y Checkout.
  static Future<SavedPaymentCard> getDefaultCard({String? defaultOwnerName}) async {
    final cards = await getCards(defaultOwnerName: defaultOwnerName);
    return cards.firstWhere(
      (c) => c.isDefault,
      orElse: () => cards.first,
    );
  }

  /// Guarda la lista completa de tarjetas en almacenamiento seguro persistente.
  static Future<void> saveCards(List<SavedPaymentCard> cards) async {
    try {
      final jsonString = jsonEncode(cards.map((c) => c.toJson()).toList());
      await _storage.write(key: _storageKey, value: jsonString);
    } catch (_) {}
  }

  /// Añade una nueva tarjeta a la lista sincronizada.
  static Future<void> addCard(SavedPaymentCard card) async {
    final cards = await getCards();
    if (card.isDefault) {
      for (var c in cards) {
        c.isDefault = false;
      }
    } else if (cards.isEmpty) {
      card.isDefault = true;
    }
    cards.add(card);
    await saveCards(cards);
  }

  /// Establece una tarjeta específica como la predeterminada para autocarga.
  static Future<void> setDefaultCard(String cardId) async {
    final cards = await getCards();
    for (var c in cards) {
      c.isDefault = (c.id == cardId);
    }
    await saveCards(cards);
  }

  /// Elimina una tarjeta de la lista y garantiza que quede una predeterminada válida.
  static Future<void> deleteCard(String cardId) async {
    final cards = await getCards();
    final wasDefault = cards.firstWhere((c) => c.id == cardId, orElse: () => cards.first).isDefault;
    cards.removeWhere((c) => c.id == cardId);

    if (cards.isNotEmpty && wasDefault) {
      cards.first.isDefault = true;
    }
    await saveCards(cards);
  }

  /// Restablece las tarjetas a las dos por defecto iniciales (Crédito y Débito).
  static Future<List<SavedPaymentCard>> resetToDefaultCards({String? defaultOwnerName}) async {
    final defaults = getDefaultCards(defaultOwnerName: defaultOwnerName);
    await saveCards(defaults);
    return defaults;
  }
}
