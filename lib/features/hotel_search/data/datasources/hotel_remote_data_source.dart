import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/models/booking_model.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/models/room_model.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';

abstract class HotelRemoteDataSource {
  Future<List<RoomModel>> getRooms();
  Future<List<BookingModel>> getGuestBookings(String guestId);
  Future<BookingModel> createBooking({
    required int habitacionId,
    required String guestId,
    required DateTime checkIn,
    required DateTime checkOut,
    required double montoTotal,
    required int cantidadHuespedes,
    List<CompanionGuest> acompanantes = const [],
  });
  Future<bool> registerFolioPayment({
    required String folioId,
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? reference,
  });
}

class HotelRemoteDataSourceImpl implements HotelRemoteDataSource {
  final SupabaseClient supabaseClient;

  HotelRemoteDataSourceImpl(this.supabaseClient);

  @override
  Future<List<RoomModel>> getRooms() async {
    try {
      final response = await supabaseClient
          .from('habitaciones')
          .select('*, tipos_habitacion(*), reservas(*)')
          .order('id', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => RoomModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al cargar habitaciones: ${e.toString()}');
    }
  }

  @override
  Future<List<BookingModel>> getGuestBookings(String guestId) async {
    try {
      final response = await supabaseClient
          .from('reservas')
          .select('*, habitaciones(*, tipos_habitacion(*)), folios(*)')
          .eq('guest_id', guestId)
          .order('id', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => BookingModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al cargar reservas del huésped: ${e.toString()}');
    }
  }

  @override
  Future<BookingModel> createBooking({
    required int habitacionId,
    required String guestId,
    required DateTime checkIn,
    required DateTime checkOut,
    required double montoTotal,
    required int cantidadHuespedes,
    List<CompanionGuest> acompanantes = const [],
  }) async {
    try {
      final checkInStr = checkIn.toIso8601String().split('T')[0];
      final checkOutStr = checkOut.toIso8601String().split('T')[0];

      final existingConflicts = await supabaseClient
          .from('reservas')
          .select('id')
          .eq('habitacion_id', habitacionId)
          .inFilter('estado', ['Confirmada', 'Check-in', 'En curso', 'Ocupada'])
          .lt('check_in_previsto', checkOutStr)
          .gt('check_out_previsto', checkInStr);

      if ((existingConflicts as List).isNotEmpty) {
        throw Exception('Esta habitación ya cuenta con una reserva en el rango de fechas seleccionado. Por favor elige otras fechas libres o consulta el calendario.');
      }

      final codigoReserva = 'RES-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      Map<String, dynamic> bookingResponse;
      try {
        final resp = await supabaseClient.from('reservas').insert({
          'codigo_reserva': codigoReserva,
          'guest_id': guestId,
          'habitacion_id': habitacionId,
          'check_in_previsto': checkInStr,
          'check_out_previsto': checkOutStr,
          'cantidad_huespedes': cantidadHuespedes,
          'monto_total': montoTotal,
          'canal_venta': 'App Móvil',
          'estado': 'Confirmada',
        }).select('*, habitaciones(*, tipos_habitacion(*))').single();
        bookingResponse = Map<String, dynamic>.from(resp);
      } catch (_) {
        final resp = await supabaseClient.from('reservas').insert({
          'codigo_reserva': codigoReserva,
          'guest_id': guestId,
          'habitacion_id': habitacionId,
          'check_in_previsto': checkInStr,
          'check_out_previsto': checkOutStr,
          'cantidad_huespedes': cantidadHuespedes,
          'monto_total': montoTotal,
          'canal_venta': 'App Móvil',
          'estado': 'Confirmada',
        }).select().single();
        bookingResponse = Map<String, dynamic>.from(resp);
      }

      final bookingId = bookingResponse['id'].toString();

      Map<String, dynamic>? folioResponse;
      try {
        final fResp = await supabaseClient.from('folios').insert({
          'reserva_id': bookingId,
          'guest_id': guestId,
          'total_alojamiento': montoTotal,
          'saldo_pendiente': montoTotal,
          'total_pagos': 0,
          'estado': 'Abierto',
        }).select().single();
        folioResponse = Map<String, dynamic>.from(fResp);
      } catch (_) {
        await supabaseClient.from('folios').insert({
          'reserva_id': bookingId,
          'guest_id': guestId,
          'total_alojamiento': montoTotal,
          'saldo_pendiente': montoTotal,
          'estado': 'Abierto',
        });
      }

      if (folioResponse != null) {
        bookingResponse['folios'] = [folioResponse];
      }

      if (acompanantes.isNotEmpty) {
        try {
          final fullRows = acompanantes.map((a) => a.toMap(bookingId)).toList();
          await supabaseClient.from('acompanantes').insert(fullRows);
        } catch (_) {
          try {
            final fallbackRows = acompanantes.map((a) => {
              'reserva_id': bookingId,
              'full_name': a.fullName.trim(),
              'document_number': a.legalDocumentSummary,
            }).toList();
            await supabaseClient.from('acompanantes').insert(fallbackRows);
          } catch (_) {}
        }
      }

      try {
        await supabaseClient
            .from('habitaciones')
            .update({'estado': 'Reservada'})
            .eq('id', habitacionId);
      } catch (_) {}

      return BookingModel.fromJson(bookingResponse);
    } catch (e) {
      throw Exception('Error al crear la reserva: ${e.toString()}');
    }
  }

  @override
  Future<bool> registerFolioPayment({
    required String folioId,
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? reference,
  }) async {
    try {
      final folioData = await supabaseClient
          .from('folios')
          .select('saldo_pendiente, total_pagos, total_alojamiento')
          .eq('id', folioId)
          .maybeSingle();

      double currentSaldo = 0.0;
      double currentPagos = 0.0;
      if (folioData != null) {
        final rawSaldo = folioData['saldo_pendiente'];
        final rawPagos = folioData['total_pagos'];
        currentSaldo = rawSaldo is num ? rawSaldo.toDouble() : double.tryParse(rawSaldo?.toString() ?? '') ?? 0.0;
        currentPagos = rawPagos is num ? rawPagos.toDouble() : double.tryParse(rawPagos?.toString() ?? '') ?? 0.0;
      }

      final newTotalPagos = currentPagos + amount;
      final newSaldo = (currentSaldo - amount).clamp(0.0, double.infinity);
      final nuevoEstado = newSaldo <= 0 ? 'Cerrado' : 'Abierto';

      await supabaseClient.from('folios').update({
        'total_pagos': newTotalPagos,
        'saldo_pendiente': newSaldo,
        'estado': nuevoEstado,
      }).eq('id', folioId);

      // Sincronizar anticipo_pagado en la tabla reservas
      if (bookingId.isNotEmpty) {
        try {
          await supabaseClient.from('reservas').update({
            'anticipo_pagado': newTotalPagos,
          }).eq('id', bookingId);
        } catch (e) {
          debugPrint('Nota: no se pudo actualizar anticipo_pagado en reservas: $e');
        }
      }

      // Normalizar método de pago para el check constraint de Supabase:
      // ('Tarjeta Credito', 'Tarjeta Debito', 'Transferencia', 'QR', 'Efectivo')
      String normalizedMethod = 'Tarjeta Debito';
      final lower = paymentMethod.toLowerCase();
      if (lower.contains('credito') || lower.contains('crédito')) {
        normalizedMethod = 'Tarjeta Credito';
      } else if (lower.contains('debito') || lower.contains('débito') || lower.contains('tarjeta')) {
        normalizedMethod = 'Tarjeta Debito';
      } else if (lower.contains('sipap') || lower.contains('transferencia') || lower.contains('bancaria')) {
        normalizedMethod = 'Transferencia';
      } else if (lower.contains('billetera') || lower.contains('qr')) {
        normalizedMethod = 'QR';
      } else if (lower.contains('efectivo')) {
        normalizedMethod = 'Efectivo';
      }

      try {
        await supabaseClient.from('pagos_folio').insert({
          'folio_id': folioId,
          'monto': amount,
          'metodo_pago': normalizedMethod,
          'referencia_transaccion': reference ?? 'Abono / Adelanto App Móvil',
        });
      } catch (e) {
        debugPrint('Nota: tabla pagos_folio insert: $e');
      }

      try {
        final channel = supabaseClient.channel('hotel_universal_sync');
        await channel.sendBroadcastMessage(
          event: 'hotel_data_updated',
          payload: {'table': 'folios', 'id': folioId, 'action': 'payment'},
        );
      } catch (_) {}

      return true;
    } catch (e) {
      throw Exception('Error al registrar el pago: ${e.toString()}');
    }
  }
}
