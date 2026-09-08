import 'package:equatable/equatable.dart';

class Booking extends Equatable {
  final String id;
  final String codigoReserva;
  final String guestId;
  final int habitacionId;
  final String habitacionNumero;
  final String habitacionTipo;
  final String checkInPrevisto;
  final String checkOutPrevisto;
  final int cantidadHuespedes;
  final double montoTotal;
  final String estado;
  final String canalVenta;
  final String? folioId;
  final double folioSaldoPendiente;
  final double folioTotalPagos;
  final String folioEstado;
  final double totalConsumos;
  final double totalServicios;
  final double totalCargos;
  final String ratePlanType;
  final String? cancellationStatus;
  final double? cancellationPenaltyAmount;
  final double? refundAmount;
  final String? cancelledAt;

  const Booking({
    required this.id,
    required this.codigoReserva,
    required this.guestId,
    required this.habitacionId,
    required this.habitacionNumero,
    required this.habitacionTipo,
    required this.checkInPrevisto,
    required this.checkOutPrevisto,
    required this.cantidadHuespedes,
    required this.montoTotal,
    required this.estado,
    required this.canalVenta,
    this.folioId,
    double? folioSaldoPendiente,
    double? folioTotalPagos,
    required this.folioEstado,
    double? totalConsumos,
    double? totalServicios,
    double? totalCargos,
    String? ratePlanType,
    this.cancellationStatus,
    this.cancellationPenaltyAmount,
    this.refundAmount,
    this.cancelledAt,
  })  : folioSaldoPendiente = folioSaldoPendiente ?? montoTotal,
        folioTotalPagos = folioTotalPagos ?? 0.0,
        totalConsumos = totalConsumos ?? 0.0,
        totalServicios = totalServicios ?? 0.0,
        totalCargos = totalCargos ?? 0.0,
        ratePlanType = ratePlanType ?? 'Flexible';

  int get noches {
    try {
      final inDate = DateTime.tryParse(checkInPrevisto);
      final outDate = DateTime.tryParse(checkOutPrevisto);
      if (inDate != null && outDate != null) {
        final diff = outDate.difference(inDate).inDays;
        return diff > 0 ? diff : 1;
      }
    } catch (_) {}
    return 1;
  }

  double get tarifaPorNoche => noches > 0 ? (montoTotal / noches) : montoTotal;
  double get iva10 => montoTotal / 11;
  double get granTotalGastos => montoTotal + totalConsumos + totalServicios + totalCargos;

  bool get isFlexibleRate => ratePlanType.toLowerCase().contains('flex');
  bool get isCancelled => estado.toLowerCase().contains('cancelad');

  DateTime? get checkInOfficialDateTime {
    try {
      final dateOnly = DateTime.tryParse(checkInPrevisto);
      if (dateOnly != null) {
        // Hora oficial de Check-in: 14:00 hs
        return DateTime(dateOnly.year, dateOnly.month, dateOnly.day, 14, 0, 0);
      }
    } catch (_) {}
    return null;
  }

  double get hoursUntilCheckIn {
    final official = checkInOfficialDateTime;
    if (official == null) return 0.0;
    final diff = official.difference(DateTime.now());
    return diff.inMinutes / 60.0;
  }

  bool get isFreeCancellationEligible {
    return isFlexibleRate && hoursUntilCheckIn > 24.0;
  }

  @override
  List<Object?> get props => [
        id,
        codigoReserva,
        guestId,
        habitacionId,
        estado,
        folioSaldoPendiente,
        folioTotalPagos,
        totalConsumos,
        totalServicios,
        totalCargos,
        ratePlanType,
        cancellationStatus,
        cancellationPenaltyAmount,
        refundAmount,
        cancelledAt,
      ];
}
