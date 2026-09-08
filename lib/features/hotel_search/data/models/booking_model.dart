import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';

class BookingModel extends Booking {
  const BookingModel({
    required super.id,
    required super.codigoReserva,
    required super.guestId,
    required super.habitacionId,
    required super.habitacionNumero,
    required super.habitacionTipo,
    required super.checkInPrevisto,
    required super.checkOutPrevisto,
    required super.cantidadHuespedes,
    required super.montoTotal,
    required super.estado,
    required super.canalVenta,
    super.folioId,
    required super.folioSaldoPendiente,
    required super.folioTotalPagos,
    required super.folioEstado,
    super.totalConsumos = 0.0,
    super.totalServicios = 0.0,
    super.totalCargos = 0.0,
    super.ratePlanType = 'Flexible',
    super.cancellationStatus,
    super.cancellationPenaltyAmount,
    super.refundAmount,
    super.cancelledAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final hab = json['habitaciones'] as Map<String, dynamic>? ?? {};
    final tipo = hab['tipos_habitacion'] as Map<String, dynamic>? ?? {};
    
    // Extraer folio si existe (puede venir como lista o como mapa)
    Map<String, dynamic>? folio;
    if (json['folios'] is List && (json['folios'] as List).isNotEmpty) {
      folio = (json['folios'] as List).first as Map<String, dynamic>?;
    } else if (json['folios'] is Map<String, dynamic>) {
      folio = json['folios'] as Map<String, dynamic>;
    }

    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    final totalAlojamiento = parseDouble(json['monto_total']);
    final totalPagado = parseDouble(folio?['total_pagos']);
    final totalConsumos = parseDouble(folio?['total_consumos']);
    final totalServicios = parseDouble(folio?['total_servicios']);
    final totalCargos = parseDouble(folio?['total_cargos']);
    final saldoPendiente = parseDouble(folio?['saldo_pendiente'], totalAlojamiento);

    final rawPlan = json['rate_plan_type'] ?? json['rate_plan'] ?? json['plan_tarifa'] ?? 'Flexible';
    final ratePlanType = rawPlan.toString().trim().isEmpty ? 'Flexible' : rawPlan.toString().trim();

    return BookingModel(
      id: json['id']?.toString() ?? '',
      codigoReserva: json['codigo_reserva'] ?? 'RES-000',
      guestId: json['guest_id']?.toString() ?? '',
      habitacionId: json['habitacion_id'] is int
          ? json['habitacion_id']
          : int.tryParse(json['habitacion_id']?.toString() ?? '1') ?? 1,
      habitacionNumero: hab['numero'] ?? 'S/N',
      habitacionTipo: tipo['nombre'] ?? 'Habitación',
      checkInPrevisto: json['check_in_previsto'] ?? '',
      checkOutPrevisto: json['check_out_previsto'] ?? '',
      cantidadHuespedes: json['cantidad_huespedes'] is int
          ? json['cantidad_huespedes']
          : int.tryParse(json['cantidad_huespedes']?.toString() ?? '1') ?? 1,
      montoTotal: totalAlojamiento,
      estado: json['estado'] ?? 'Confirmada',
      canalVenta: json['canal_venta'] ?? 'App Móvil',
      folioId: folio?['id']?.toString(),
      folioSaldoPendiente: saldoPendiente,
      folioTotalPagos: totalPagado,
      folioEstado: folio?['estado'] ?? 'Abierto',
      totalConsumos: totalConsumos,
      totalServicios: totalServicios,
      totalCargos: totalCargos,
      ratePlanType: ratePlanType,
      cancellationStatus: json['cancellation_status']?.toString(),
      cancellationPenaltyAmount: json['cancellation_penalty_amount'] != null
          ? parseDouble(json['cancellation_penalty_amount'])
          : null,
      refundAmount: json['refund_amount'] != null
          ? parseDouble(json['refund_amount'])
          : null,
      cancelledAt: json['cancelled_at']?.toString(),
    );
  }
}
