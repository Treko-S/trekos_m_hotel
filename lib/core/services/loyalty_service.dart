import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:trekos_m_hotel/features/auth/domain/entities/user.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';

enum LoyaltyTier { plata, oro, platino, diamante }

class LoyaltyTransaction {
  final String id;
  final String title;
  final String subtitle;
  final int points; // positivo = ganado, negativo = canjeado
  final DateTime date;
  final String iconType; // 'welcome', 'booking', 'app_bonus', 'checkout', 'review', 'service', 'redeem'

  const LoyaltyTransaction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.date,
    required this.iconType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'points': points,
        'date': date.toIso8601String(),
        'iconType': iconType,
      };

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) => LoyaltyTransaction(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        points: (json['points'] as num).toInt(),
        date: DateTime.parse(json['date'] as String),
        iconType: json['iconType'] as String? ?? 'booking',
      );
}

class LoyaltyReward {
  final String id;
  final String title;
  final int pointsRequired;
  final IconData icon;
  final String description;
  final String category;

  const LoyaltyReward({
    required this.id,
    required this.title,
    required this.pointsRequired,
    required this.icon,
    required this.description,
    required this.category,
  });
}

class LoyaltyVoucher {
  final String id;
  final String code;
  final String rewardTitle;
  final int pointsSpent;
  final DateTime redeemedAt;
  final String expiresAt;
  final String qrData;
  final bool isUsed;

  const LoyaltyVoucher({
    required this.id,
    required this.code,
    required this.rewardTitle,
    required this.pointsSpent,
    required this.redeemedAt,
    required this.expiresAt,
    required this.qrData,
    this.isUsed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'rewardTitle': rewardTitle,
        'pointsSpent': pointsSpent,
        'redeemedAt': redeemedAt.toIso8601String(),
        'expiresAt': expiresAt,
        'qrData': qrData,
        'isUsed': isUsed,
      };

  factory LoyaltyVoucher.fromJson(Map<String, dynamic> json) => LoyaltyVoucher(
        id: json['id'] as String,
        code: json['code'] as String,
        rewardTitle: json['rewardTitle'] as String,
        pointsSpent: (json['pointsSpent'] as num).toInt(),
        redeemedAt: DateTime.parse(json['redeemedAt'] as String),
        expiresAt: json['expiresAt'] as String,
        qrData: json['qrData'] as String,
        isUsed: json['isUsed'] as bool? ?? false,
      );
}

class LoyaltyProfile {
  final String userId;
  final String userName;
  final String membershipNumber;
  final int totalPoints;
  final int lifetimePoints;
  final LoyaltyTier tier;
  final String tierName;
  final String tierBadge;
  final List<Color> tierGradient;
  final Color accentColor;
  final double progress;
  final int pointsToNextTier;
  final String nextTierName;
  final List<String> perks;
  final List<LoyaltyTransaction> transactions;
  final List<LoyaltyVoucher> vouchers;

  const LoyaltyProfile({
    required this.userId,
    required this.userName,
    required this.membershipNumber,
    required this.totalPoints,
    required this.lifetimePoints,
    required this.tier,
    required this.tierName,
    required this.tierBadge,
    required this.tierGradient,
    required this.accentColor,
    required this.progress,
    required this.pointsToNextTier,
    required this.nextTierName,
    required this.perks,
    required this.transactions,
    required this.vouchers,
  });
}

class LoyaltyService {
  static final LoyaltyService _instance = LoyaltyService._internal();
  factory LoyaltyService() => _instance;
  LoyaltyService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const List<LoyaltyReward> catalog = [
    LoyaltyReward(
      id: 'reward_late_checkout',
      title: 'Late Check-out garantizado hasta 16:00 hs',
      pointsRequired: 400,
      icon: Icons.more_time_rounded,
      description: 'Extensión sin costo de tu horario de salida con confirmación garantizada en recepción.',
      category: 'Estadía & Confort',
    ),
    LoyaltyReward(
      id: 'reward_breakfast_2',
      title: 'Desayuno Buffet Gourmet para 2 Personas',
      pointsRequired: 750,
      icon: Icons.breakfast_dining_rounded,
      description: 'Acceso completo al buffet del restaurante principal con jugos naturales, panadería artesanal y platos calientes.',
      category: 'Gastronomía 3V',
    ),
    LoyaltyReward(
      id: 'reward_spa_massage',
      title: 'Sesión de Masaje Relajante en Spa 3V (50 min)',
      pointsRequired: 1200,
      icon: Icons.spa_rounded,
      description: 'Tratamiento corporal con aceites esenciales y aromaterapia en nuestro centro de bienestar.',
      category: 'Bienestar & Spa',
    ),
    LoyaltyReward(
      id: 'reward_gourmet_dinner',
      title: 'Cena Romántica / Gourmet en Restaurante',
      pointsRequired: 1800,
      icon: Icons.restaurant_menu_rounded,
      description: 'Menú de 3 pasos a la carta con maridaje de vinos selectos para 2 comensales.',
      category: 'Gastronomía 3V',
    ),
    LoyaltyReward(
      id: 'reward_free_night',
      title: 'Noche de Estadía Estándar de Cortesía',
      pointsRequired: 3000,
      icon: Icons.king_bed_rounded,
      description: '1 noche de alojamiento para 2 personas en habitación Standard Confort con todos los servicios incluidos.',
      category: 'Alojamiento Exclusivo',
    ),
  ];

  /// Calcula dinámicamente el perfil del Club 3V para un usuario dado
  Future<LoyaltyProfile> getProfile({
    required User user,
    required List<Booking> bookings,
  }) async {
    // 1. Membresía única a partir del ID de usuario
    final cleanId = user.id.replaceAll('-', '');
    final shortCode = cleanId.length >= 6 ? cleanId.substring(0, 6).toUpperCase() : cleanId.padRight(6, '0').toUpperCase();
    final membershipNumber = '#3V-$shortCode';

    final List<LoyaltyTransaction> transactions = [];

    // 2. Bono de Bienvenida al Club 3V (siempre otorgado a todo usuario registrado)
    transactions.add(
      LoyaltyTransaction(
        id: 'welcome_${user.id}',
        title: 'Bono de Bienvenida al Club 3V',
        subtitle: 'Acreditado por registro y activación de cuenta',
        points: 200,
        date: DateTime.now().subtract(const Duration(days: 30)),
        iconType: 'welcome',
      ),
    );

    // 3. Puntos por cada reserva del usuario
    for (final b in bookings) {
      // Puntos por importe abonado (1 pt / 1.000 Gs.)
      final montoBase = b.folioTotalPagos > 0 ? b.folioTotalPagos : b.montoTotal;
      final puntosEstadia = (montoBase / 1000).floor();
      if (puntosEstadia > 0) {
        transactions.add(
          LoyaltyTransaction(
            id: 'stay_${b.id}',
            title: 'Estadía Habitación ${b.habitacionNumero} (${b.codigoReserva})',
            subtitle: '${b.noches} noche(s) • ${NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0).format(montoBase)} Gs.',
            points: puntosEstadia,
            date: DateTime.tryParse(b.checkInPrevisto) ?? DateTime.now(),
            iconType: 'booking',
          ),
        );
      }

      // Bono por reservar desde la App Móvil
      if (b.canalVenta.toLowerCase().contains('app')) {
        transactions.add(
          LoyaltyTransaction(
            id: 'app_bonus_${b.id}',
            title: 'Bono Reserva App Móvil (${b.codigoReserva})',
            subtitle: 'Premio por reserva directa desde la aplicación',
            points: 100,
            date: DateTime.tryParse(b.checkInPrevisto) ?? DateTime.now(),
            iconType: 'app_bonus',
          ),
        );
      }

      // Bono por noche de fidelidad (50 pts / noche)
      if (b.noches > 0) {
        transactions.add(
          LoyaltyTransaction(
            id: 'nights_${b.id}',
            title: 'Puntos por Noches de Descanso (${b.noches}n)',
            subtitle: '50 pts por cada noche de confort en Hotel 3 Vagos',
            points: b.noches * 50,
            date: DateTime.tryParse(b.checkInPrevisto) ?? DateTime.now(),
            iconType: 'booking',
          ),
        );
      }

      // Bono por Check-out y Folio Finalizado
      final estado = b.estado.toLowerCase();
      if (estado.contains('finaliz') || estado.contains('check-out') || estado.contains('complet')) {
        transactions.add(
          LoyaltyTransaction(
            id: 'checkout_${b.id}',
            title: 'Bono Estadía Cumplida (${b.codigoReserva})',
            subtitle: 'Liquidación y check-out exitoso en recepción',
            points: 150,
            date: DateTime.tryParse(b.checkOutPrevisto) ?? DateTime.now(),
            iconType: 'checkout',
          ),
        );
      }

      // Consumos de Folio / Room Service
      if (b.totalConsumos > 0) {
        final puntosConsumos = (b.totalConsumos / 1000).floor();
        if (puntosConsumos > 0) {
          transactions.add(
            LoyaltyTransaction(
              id: 'consumos_${b.id}',
              title: 'Consumos de Frigobar & Room Service',
              subtitle: '${b.codigoReserva} • Total ${NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0).format(b.totalConsumos)} Gs.',
              points: puntosConsumos,
              date: DateTime.tryParse(b.checkOutPrevisto) ?? DateTime.now(),
              iconType: 'service',
            ),
          );
        }
      }
    }

    // 4. Puntos por Reseñas de Habitación (guardadas localmente)
    final reviewPointsKey = 'loyalty_reviews_points_${user.id}';
    final storedReviewPointsStr = await _storage.read(key: reviewPointsKey);
    final reviewPoints = int.tryParse(storedReviewPointsStr ?? '0') ?? 0;
    if (reviewPoints > 0) {
      final reviewsCount = reviewPoints ~/ 50;
      transactions.add(
        LoyaltyTransaction(
          id: 'reviews_${user.id}',
          title: 'Reseñas & Calificaciones de Habitaciones',
          subtitle: '$reviewsCount opinión(es) compartida(s) (+50 pts c/u)',
          points: reviewPoints,
          date: DateTime.now(),
          iconType: 'review',
        ),
      );
    }

    // 5. Canjes realizados (descuentos) y Vouchers guardados
    final vouchersKey = 'loyalty_vouchers_${user.id}';
    final storedVouchersStr = await _storage.read(key: vouchersKey);
    final List<LoyaltyVoucher> vouchers = [];
    if (storedVouchersStr != null && storedVouchersStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(storedVouchersStr);
        for (var item in decoded) {
          final v = LoyaltyVoucher.fromJson(item as Map<String, dynamic>);
          vouchers.add(v);
          transactions.add(
            LoyaltyTransaction(
              id: 'redeem_${v.id}',
              title: 'Canje: ${v.rewardTitle}',
              subtitle: 'Voucher #${v.code} emitido',
              points: -v.pointsSpent,
              date: v.redeemedAt,
              iconType: 'redeem',
            ),
          );
        }
      } catch (e) {
        debugPrint('Error decodificando vouchers de lealtad: $e');
      }
    }

    // Ordenar transacciones por fecha descendente
    transactions.sort((a, b) => b.date.compareTo(a.date));

    // 6. Totales acumulados
    int lifetimePoints = 0;
    int totalPoints = 0;
    for (final t in transactions) {
      totalPoints += t.points;
      if (t.points > 0) {
        lifetimePoints += t.points;
      }
    }
    if (totalPoints < 0) totalPoints = 0;

    // 7. Cálculo de Tier y Progreso
    LoyaltyTier tier;
    String tierName;
    String tierBadge;
    List<Color> tierGradient;
    Color accentColor;
    double progress;
    int pointsToNextTier;
    String nextTierName;
    List<String> perks;

    if (totalPoints >= 3000) {
      tier = LoyaltyTier.diamante;
      tierName = 'Socio Diamante Élite';
      tierBadge = 'SOCIO DIAMANTE ÉLITE';
      tierGradient = const [Color(0xFFA855F7), Color(0xFF7E22CE)];
      accentColor = const Color(0xFFF3E8FF);
      progress = 1.0;
      pointsToNextTier = 0;
      nextTierName = 'Nivel Máximo Alcanzado 👑';
      perks = const [
        '1 Noche Anual Gratis',
        'Transfer Privado Aeropuerto',
        'Late Check-out 18:00 hs',
        'Concierge VIP 24/7',
      ];
    } else if (totalPoints >= 1500) {
      tier = LoyaltyTier.platino;
      tierName = 'Socio Platino VIP';
      tierBadge = 'SOCIO PLATINO VIP';
      tierGradient = const [Color(0xFF38BDF8), Color(0xFF0284C7)];
      accentColor = const Color(0xFFBAE6FD);
      progress = ((totalPoints - 1500) / 1500).clamp(0.0, 1.0);
      pointsToNextTier = 3000 - totalPoints;
      nextTierName = 'Faltan $pointsToNextTier pts para Diamante 👑';
      perks = const [
        'Upgrade de Habitación',
        '20% OFF Room Service & Spa',
        'Desayuno Buffet Incluido',
        'Acceso Lounge VIP',
      ];
    } else if (totalPoints >= 500) {
      tier = LoyaltyTier.oro;
      tierName = 'Socio Oro VIP';
      tierBadge = 'SOCIO ORO VIP';
      tierGradient = const [Color(0xFFF59E0B), Color(0xFFD97706)];
      accentColor = const Color(0xFFFDE68A);
      progress = ((totalPoints - 500) / 1000).clamp(0.0, 1.0);
      pointsToNextTier = 1500 - totalPoints;
      nextTierName = 'Faltan $pointsToNextTier pts para Platino 💎';
      perks = const [
        'Early / Late Check-in',
        '10% OFF Frigobar & Restó',
        'Welcome Drink de Bienvenida',
      ];
    } else {
      tier = LoyaltyTier.plata;
      tierName = 'Socio Plata';
      tierBadge = 'SOCIO PLATA';
      tierGradient = const [Color(0xFF94A3B8), Color(0xFF64748B)];
      accentColor = const Color(0xFFE2E8F0);
      progress = (totalPoints / 500).clamp(0.0, 1.0);
      pointsToNextTier = 500 - totalPoints;
      nextTierName = 'Faltan $pointsToNextTier pts para Oro 🥇';
      perks = const [
        'Wi-Fi Premium 100 Mbps',
        'Cafetería de Cortesía',
        'Acumula 1 pt / 1.000 Gs.',
      ];
    }

    return LoyaltyProfile(
      userId: user.id,
      userName: user.name,
      membershipNumber: membershipNumber,
      totalPoints: totalPoints,
      lifetimePoints: lifetimePoints,
      tier: tier,
      tierName: tierName,
      tierBadge: tierBadge,
      tierGradient: tierGradient,
      accentColor: accentColor,
      progress: progress,
      pointsToNextTier: pointsToNextTier,
      nextTierName: nextTierName,
      perks: perks,
      transactions: transactions,
      vouchers: vouchers,
    );
  }

  /// Otorga +50 puntos al usuario por dejar una reseña de habitación
  Future<void> awardReviewPoints(String userId) async {
    final reviewPointsKey = 'loyalty_reviews_points_$userId';
    final stored = await _storage.read(key: reviewPointsKey);
    final current = int.tryParse(stored ?? '0') ?? 0;
    await _storage.write(key: reviewPointsKey, value: (current + 50).toString());
  }

  /// Realiza el canje de un premio por puntos, guardando el voucher
  Future<LoyaltyVoucher?> redeemReward({
    required User user,
    required List<Booking> bookings,
    required LoyaltyReward reward,
  }) async {
    final profile = await getProfile(user: user, bookings: bookings);
    if (profile.totalPoints < reward.pointsRequired) {
      return null;
    }

    final randSuffix = (DateTime.now().millisecondsSinceEpoch % 90000 + 10000).toString();
    final code = '3V-${reward.id.split('_').last.toUpperCase()}-$randSuffix';
    final expires = DateTime.now().add(const Duration(days: 90));
    final expiresStr = DateFormat('dd/MM/yyyy').format(expires);

    final voucher = LoyaltyVoucher(
      id: 'vouch_${DateTime.now().millisecondsSinceEpoch}',
      code: code,
      rewardTitle: reward.title,
      pointsSpent: reward.pointsRequired,
      redeemedAt: DateTime.now(),
      expiresAt: expiresStr,
      qrData: 'HOTEL3VAGOS|VOUCHER|$code|USER|${user.id}|PTS|${reward.pointsRequired}',
    );

    final vouchersKey = 'loyalty_vouchers_${user.id}';
    final storedVouchersStr = await _storage.read(key: vouchersKey);
    final List<dynamic> list = storedVouchersStr != null && storedVouchersStr.isNotEmpty
        ? jsonDecode(storedVouchersStr)
        : [];
    list.insert(0, voucher.toJson());
    await _storage.write(key: vouchersKey, value: jsonEncode(list));

    return voucher;
  }
}
