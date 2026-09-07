import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Representa un rango de fechas ocupado o reservado para una habitación.
class RoomBookedRange extends Equatable {
  final DateTime checkIn;
  final DateTime checkOut;
  final String? codigoReserva;
  final String? estado;

  const RoomBookedRange({
    required this.checkIn,
    required this.checkOut,
    this.codigoReserva,
    this.estado,
  });

  /// Determina si un rango propuesto de fechas [otherCheckIn, otherCheckOut]
  /// colisiona con esta reserva.
  /// (Permite checkout por la mañana e ingreso por la tarde en el mismo día).
  bool overlaps(DateTime otherCheckIn, DateTime otherCheckOut) {
    return otherCheckIn.isBefore(checkOut) && otherCheckOut.isAfter(checkIn);
  }

  @override
  List<Object?> get props => [checkIn, checkOut, codigoReserva, estado];
}

class Room extends Equatable {
  final int id;
  final String numero;
  final int tipoId;
  final String tipoNombre;
  final String tipoDescripcion;
  final int capacidad;
  final double precioBase;
  final int piso;
  final String estado;
  final Map<String, dynamic> caracteristicas;
  final String? observaciones;
  final String? imagenCover;
  final List<String> imagenes;
  final DateTime? fechaDisponibleDesde;
  final List<RoomBookedRange>? _bookedRanges;

  /// Retorna la lista de rangos reservados garantizando que nunca sea nula.
  List<RoomBookedRange> get bookedRanges => _bookedRanges ?? const [];

  const Room({
    required this.id,
    required this.numero,
    required this.tipoId,
    required this.tipoNombre,
    required this.tipoDescripcion,
    required this.capacidad,
    required this.precioBase,
    required this.piso,
    required this.estado,
    required this.caracteristicas,
    this.observaciones,
    this.imagenCover,
    this.imagenes = const [],
    this.fechaDisponibleDesde,
    List<RoomBookedRange>? bookedRanges,
  }) : _bookedRanges = bookedRanges;

  /// Estado público para la interfaz del cliente/huésped:
  /// - 'Disponible': si la habitación está lista para reservar.
  /// - 'Ocupada': si está ocupada o reservada actualmente.
  /// - 'No disponible': para cualquier estado operativo interno como "Check-out pendiente",
  ///   "Sucia", "En limpieza", "Inspección", "Mantenimiento", "Bloqueada", "Fuera de servicio".
  String get estadoPublico {
    final est = estado.toLowerCase().trim();
    if (est == 'disponible') return 'Disponible';
    if (est == 'ocupada' || est == 'ocupado' || est == 'reservada' || est == 'reservado') {
      return 'Ocupada';
    }
    return 'No disponible';
  }

  /// Indica si la habitación está totalmente libre en el momento actual para ingreso inmediato.
  bool get isAvailableForGuest => estado.toLowerCase().trim() == 'disponible';

  /// Indica si la habitación es apta para ser reservada:
  /// Tanto si está disponible ahora como si está ocupada pero con posibilidad de reservar fechas futuras.
  bool get canBeBooked => estadoPublico == 'Disponible' || estadoPublico == 'Ocupada';

  /// Verifica si un rango de fechas [checkIn, checkOut] no colisiona con ninguna reserva existente.
  bool isDateRangeAvailable(DateTime checkIn, DateTime checkOut) {
    if (checkOut.isBefore(checkIn) || checkOut.isAtSameMomentAs(checkIn)) {
      return false;
    }
    for (final range in bookedRanges) {
      if (range.overlaps(checkIn, checkOut)) {
        return false;
      }
    }
    return true;
  }

  /// Indica si la habitación tiene una reserva inminente (hoy o mañana) que impida el ingreso inmediato.
  bool get hasImminentBooking {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return !isDateRangeAvailable(today, tomorrow.add(const Duration(days: 1)));
  }

  /// Indica si la habitación está verdaderamente libre y sin reservas inminentes para ingreso inmediato.
  bool get isAvailableNow => isAvailableForGuest && !hasImminentBooking;

  /// Próxima fecha sugerida de check-in disponible sin colisión de fechas.
  DateTime get nextAvailableDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var candidate = today.add(const Duration(days: 1));
    if (fechaDisponibleDesde != null && fechaDisponibleDesde!.isAfter(candidate)) {
      candidate = DateTime(fechaDisponibleDesde!.year, fechaDisponibleDesde!.month, fechaDisponibleDesde!.day);
    }

    int iterations = 0;
    while (iterations < 100) {
      iterations++;
      final nextDay = candidate.add(const Duration(days: 1));
      RoomBookedRange? collision;
      for (final range in bookedRanges) {
        if (range.overlaps(candidate, nextDay)) {
          collision = range;
          break;
        }
      }
      if (collision == null) break;
      candidate = DateTime(collision.checkOut.year, collision.checkOut.month, collision.checkOut.day);
    }
    return candidate;
  }

  /// Feedback visual informativo para habitaciones ocupadas o con reservas:
  /// e.g. "Disponible desde el 06/09/2026"
  String get textoDisponibilidad {
    if (estadoPublico == 'No disponible') {
      return 'No disponible';
    }
    if (hasImminentBooking || estadoPublico == 'Ocupada') {
      final formatted = DateFormat('dd/MM/yyyy').format(nextAvailableDate);
      return 'Disponible desde el $formatted';
    }
    if (isAvailableForGuest) {
      return 'Disponible ahora';
    }
    return 'No disponible';
  }

  @override
  List<Object?> get props => [
        id,
        numero,
        tipoNombre,
        precioBase,
        estado,
        imagenes,
        fechaDisponibleDesde,
        bookedRanges,
      ];
}

