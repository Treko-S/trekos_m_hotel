import 'package:flutter_test/flutter_test.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/models/room_model.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';

void main() {
  group('RoomBookedRange Overlap & Collision Tests', () {
    final existingBooking = RoomBookedRange(
      checkIn: DateTime(2026, 9, 10, 14, 0),
      checkOut: DateTime(2026, 9, 15, 11, 0),
      codigoReserva: 'RES-001',
      estado: 'Confirmada',
    );

    test('Solapamiento total: nueva reserva dentro del periodo reservado', () {
      final newIn = DateTime(2026, 9, 11, 14, 0);
      final newOut = DateTime(2026, 9, 13, 11, 0);
      expect(existingBooking.overlaps(newIn, newOut), isTrue);
    });

    test('Solapamiento parcial: inicia antes y termina durante el periodo reservado', () {
      final newIn = DateTime(2026, 9, 8, 14, 0);
      final newOut = DateTime(2026, 9, 12, 11, 0);
      expect(existingBooking.overlaps(newIn, newOut), isTrue);
    });

    test('Solapamiento parcial: inicia durante y termina después del periodo reservado', () {
      final newIn = DateTime(2026, 9, 14, 14, 0);
      final newOut = DateTime(2026, 9, 18, 11, 0);
      expect(existingBooking.overlaps(newIn, newOut), isTrue);
    });

    test('Solapamiento envolvente: inicia antes y termina después del periodo reservado', () {
      final newIn = DateTime(2026, 9, 5, 14, 0);
      final newOut = DateTime(2026, 9, 20, 11, 0);
      expect(existingBooking.overlaps(newIn, newOut), isTrue);
    });

    test('Transición el mismo día: salida del anterior a las 11:00 hs e ingreso del nuevo a las 14:00 hs no colisiona', () {
      // El huésped anterior sale el 15/09 a las 11:00 hs. El nuevo ingresa el 15/09 a las 14:00 hs.
      final newIn = DateTime(2026, 9, 15, 14, 0);
      final newOut = DateTime(2026, 9, 20, 11, 0);
      expect(existingBooking.overlaps(newIn, newOut), isFalse);
    });

    test('Transición el mismo día: salida del nuevo antes o al inicio del check-in del siguiente no colisiona', () {
      final newIn = DateTime(2026, 9, 5, 14, 0);
      final newOut = DateTime(2026, 9, 10, 11, 0);
      expect(existingBooking.overlaps(newIn, newOut), isFalse);
    });

    test('Periodos completamente libres antes o después no colisionan', () {
      final beforeIn = DateTime(2026, 9, 1, 14, 0);
      final beforeOut = DateTime(2026, 9, 5, 11, 0);
      expect(existingBooking.overlaps(beforeIn, beforeOut), isFalse);

      final afterIn = DateTime(2026, 9, 20, 14, 0);
      final afterOut = DateTime(2026, 9, 25, 11, 0);
      expect(existingBooking.overlaps(afterIn, afterOut), isFalse);
    });
  });

  group('Room.canBeBooked & isDateRangeAvailable Tests', () {
    final bookedRange1 = RoomBookedRange(
      checkIn: DateTime(2026, 9, 1, 14, 0),
      checkOut: DateTime(2026, 9, 7, 11, 0),
      codigoReserva: 'RES-001',
      estado: 'Ocupada',
    );
    final bookedRange2 = RoomBookedRange(
      checkIn: DateTime(2026, 9, 15, 14, 0),
      checkOut: DateTime(2026, 9, 20, 11, 0),
      codigoReserva: 'RES-002',
      estado: 'Confirmada',
    );

    final room = Room(
      id: 101,
      numero: '101',
      tipoId: 1,
      tipoNombre: 'Standard Single',
      tipoDescripcion: 'Habitación cómoda',
      capacidad: 2,
      precioBase: 180000,
      piso: 1,
      estado: 'Ocupada',
      caracteristicas: const {'wifi': true},
      fechaDisponibleDesde: DateTime(2026, 9, 7, 11, 0),
      bookedRanges: [bookedRange1, bookedRange2],
    );

    test('Una habitación ocupada puede ser reservada para fechas libres (canBeBooked = true)', () {
      expect(room.estadoPublico, equals('Ocupada'));
      expect(room.isAvailableForGuest, isFalse); // No está libre hoy
      expect(room.canBeBooked, isTrue); // Pero SÍ puede reservarse para fechas posteriores
    });

    test('Habitación en mantenimiento no puede ser reservada (canBeBooked = false)', () {
      final maintenanceRoom = Room(
        id: 102,
        numero: '102',
        tipoId: 1,
        tipoNombre: 'Standard Single',
        tipoDescripcion: 'Habitación cómoda',
        capacidad: 2,
        precioBase: 180000,
        piso: 1,
        estado: 'Mantenimiento',
        caracteristicas: const {'wifi': true},
      );
      expect(maintenanceRoom.estadoPublico, equals('No disponible'));
      expect(maintenanceRoom.canBeBooked, isFalse);
    });

    test('Permite reservar en la ventana libre entre dos reservas existentes', () {
      // Entre el 07/09 y el 15/09 la habitación está libre
      final freeIn = DateTime(2026, 9, 7, 14, 0);
      final freeOut = DateTime(2026, 9, 12, 11, 0);
      expect(room.isDateRangeAvailable(freeIn, freeOut), isTrue);
    });

    test('Permite reservar después de la última reserva futura', () {
      // Después del 20/09 la habitación está libre
      final freeIn = DateTime(2026, 9, 22, 14, 0);
      final freeOut = DateTime(2026, 9, 26, 11, 0);
      expect(room.isDateRangeAvailable(freeIn, freeOut), isTrue);
    });

    test('Rechaza reserva si colisiona con el primer o segundo periodo reservado', () {
      // Colisión con el primer rango (01/09 al 07/09)
      final col1In = DateTime(2026, 9, 4, 14, 0);
      final col1Out = DateTime(2026, 9, 8, 11, 0);
      expect(room.isDateRangeAvailable(col1In, col1Out), isFalse);

      // Colisión con el segundo rango (15/09 al 20/09)
      final col2In = DateTime(2026, 9, 14, 14, 0);
      final col2Out = DateTime(2026, 9, 17, 11, 0);
      expect(room.isDateRangeAvailable(col2In, col2Out), isFalse);
    });
  });

  group('RoomModel.fromJson Multi-Date Booking Mapping Tests', () {
    test('Habitación libre hoy pero con reserva a 3 meses: permanece Disponible con bookedRanges', () {
      final json = {
        'id': 201,
        'numero': '201',
        'piso': 2,
        'estado': 'Disponible',
        'tipos_habitacion': {
          'id': 1,
          'nombre': 'Standard Single',
          'capacidad_personas': 2,
          'precio_base_noche': 180000,
        },
        'caracteristicas': {'wifi': true},
        'reservas': [
          {
            'codigo_reserva': 'RES-FUTURE-99',
            'estado': 'Confirmada',
            'check_in_previsto': '2026-12-01',
            'check_out_previsto': '2026-12-05',
          }
        ]
      };

      final roomModel = RoomModel.fromJson(json);
      expect(roomModel.estado, equals('Disponible'));
      expect(roomModel.isAvailableForGuest, isTrue);
      expect(roomModel.bookedRanges.length, equals(1));
      expect(roomModel.bookedRanges.first.codigoReserva, equals('RES-FUTURE-99'));

      // Verificar que se puede reservar para fechas que no colisionan
      expect(
        roomModel.isDateRangeAvailable(
          DateTime(2026, 11, 10, 14, 0),
          DateTime(2026, 11, 15, 11, 0),
        ),
        isTrue,
      );

      // Verificar que NO se puede reservar sobre la fecha futura de diciembre
      expect(
        roomModel.isDateRangeAvailable(
          DateTime(2026, 12, 2, 14, 0),
          DateTime(2026, 12, 4, 11, 0),
        ),
        isFalse,
      );
    });

    test('Instancia con bookedRanges nulo (simulación Hot Reload) es 100% segura y no arroja error', () {
      final legacyRoom = Room(
        id: 999,
        numero: '999',
        tipoId: 1,
        tipoNombre: 'Standard Single',
        tipoDescripcion: 'Desc',
        capacidad: 1,
        precioBase: 100000,
        piso: 1,
        estado: 'Ocupada',
        caracteristicas: const {},
        bookedRanges: null,
      );
      expect(legacyRoom.bookedRanges, isNotNull);
      expect(legacyRoom.bookedRanges, isEmpty);
      expect(
        legacyRoom.isDateRangeAvailable(
          DateTime.now(),
          DateTime.now().add(const Duration(days: 2)),
        ),
        isTrue,
      );
    });
  });
}
