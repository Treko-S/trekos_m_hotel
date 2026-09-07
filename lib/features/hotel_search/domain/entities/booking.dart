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
  })  : folioSaldoPendiente = folioSaldoPendiente ?? montoTotal,
        folioTotalPagos = folioTotalPagos ?? 0.0,
        totalConsumos = totalConsumos ?? 0.0,
        totalServicios = totalServicios ?? 0.0,
        totalCargos = totalCargos ?? 0.0;

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
      ];
}
