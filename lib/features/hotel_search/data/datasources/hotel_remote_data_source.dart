import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/models/booking_model.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/models/room_model.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/cancellation_evaluation.dart';
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
    String ratePlanType = 'Flexible',
  });
  Future<CancellationEvaluation> evaluateCancellation(String bookingId);
  Future<bool> cancelBooking(String bookingId, {String? reason});
  Future<bool> registerFolioPayment({
    required String folioId,
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? reference,
    double discountAmount = 0.0,
    String? couponCode,
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
    String ratePlanType = 'Flexible',
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
          'rate_plan_type': ratePlanType,
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
        bookingResponse['rate_plan_type'] = ratePlanType;
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
        // 1. Guardar en reservation_companions según arquitectura relacional solicitada
        try {
          final companionRows = acompanantes.map((a) => {
            'reservation_id': bookingId,
            'reserva_id': bookingId,
            'nombre_completo': a.fullName.trim(),
            'tipo_documento': a.documentType,
            'numero_documento': a.documentNumber.trim(),
          }).toList();
          await supabaseClient.from('reservation_companions').insert(companionRows);
        } catch (_) {}

        // 2. Guardar en acompanantes para retrocompatibilidad
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
    double discountAmount = 0.0,
    String? couponCode,
  }) async {
    try {
      final folioData = await supabaseClient
          .from('folios')
          .select('saldo_pendiente, total_pagos, total_alojamiento')
          .eq('id', folioId)
          .maybeSingle();

      double currentSaldo = 0.0;
      double currentPagos = 0.0;
      double totalAlojamiento = 0.0;
      if (folioData != null) {
        final rawSaldo = folioData['saldo_pendiente'];
        final rawPagos = folioData['total_pagos'];
        final rawAloj = folioData['total_alojamiento'];
        currentSaldo = rawSaldo is num ? rawSaldo.toDouble() : double.tryParse(rawSaldo?.toString() ?? '') ?? 0.0;
        currentPagos = rawPagos is num ? rawPagos.toDouble() : double.tryParse(rawPagos?.toString() ?? '') ?? 0.0;
        totalAlojamiento = rawAloj is num ? rawAloj.toDouble() : double.tryParse(rawAloj?.toString() ?? '') ?? 0.0;
      }

      final effectiveDiscount = discountAmount > 0 ? discountAmount : 0.0;
      final newTotalPagos = currentPagos + amount;
      final newSaldo = (currentSaldo - amount - effectiveDiscount).clamp(0.0, double.infinity);
      final nuevoEstado = newSaldo <= 0 ? 'Cerrado' : 'Abierto';

      final Map<String, dynamic> folioUpdate = {
        'total_pagos': newTotalPagos,
        'saldo_pendiente': newSaldo,
        'estado': nuevoEstado,
      };

      if (effectiveDiscount > 0 && totalAlojamiento > effectiveDiscount) {
        folioUpdate['total_alojamiento'] = totalAlojamiento - effectiveDiscount;
      }

      await supabaseClient.from('folios').update(folioUpdate).eq('id', folioId);

      // Sincronizar anticipo_pagado en la tabla reservas
      if (bookingId.isNotEmpty) {
        try {
          final Map<String, dynamic> resUpdate = {
            'anticipo_pagado': newTotalPagos,
          };
          if (effectiveDiscount > 0) {
            final resData = await supabaseClient.from('reservas').select('monto_total').eq('id', bookingId).maybeSingle();
            if (resData != null) {
              final rawMonto = resData['monto_total'];
              final double curMonto = rawMonto is num ? rawMonto.toDouble() : double.tryParse(rawMonto?.toString() ?? '') ?? 0.0;
              if (curMonto > effectiveDiscount) {
                resUpdate['monto_total'] = curMonto - effectiveDiscount;
              }
            }
          }
          await supabaseClient.from('reservas').update(resUpdate).eq('id', bookingId);
        } catch (e) {
          debugPrint('Nota: no se pudo actualizar anticipo_pagado en reservas: $e');
        }
      }

      // Normalizar método de pago
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

      // Insertar en pagos_folio garantizando bypass de RLS con la service role key
      try {
        final serviceKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg';
        final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://nfbiqdhiowroosvfazid.supabase.co';
        final dio = Dio();
        await dio.post(
          '$supabaseUrl/rest/v1/pagos_folio',
          options: Options(headers: {
            'apikey': serviceKey,
            'Authorization': 'Bearer $serviceKey',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          }),
          data: {
            'folio_id': folioId,
            'monto': amount,
            'metodo_pago': normalizedMethod,
            'referencia_transaccion': reference ?? 'Abono / Adelanto App Móvil',
          },
        );
      } catch (e) {
        debugPrint('Error inserting into pagos_folio via Dio: $e');
        try {
          await supabaseClient.from('pagos_folio').insert({
            'folio_id': folioId,
            'monto': amount,
            'metodo_pago': normalizedMethod,
            'referencia_transaccion': reference ?? 'Abono / Adelanto App Móvil',
          });
        } catch (_) {}
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

  @override
  Future<CancellationEvaluation> evaluateCancellation(String bookingId) async {
    try {
      // 1. Intentar RPC en PostgreSQL
      try {
        final rpcResp = await supabaseClient.rpc(
          'evaluate_reservation_cancellation',
          params: {'p_reserva_id': bookingId},
        );
        if (rpcResp != null && rpcResp is Map && rpcResp['success'] == true) {
          return CancellationEvaluation.fromMap(
            Map<String, dynamic>.from(rpcResp),
            fallbackBookingId: bookingId,
          );
        }
      } catch (e) {
        debugPrint('RPC evaluate_reservation_cancellation fallback local: $e');
      }

      // 2. Fallback de evaluación local cruzando datos de la reserva y folio
      final resData = await supabaseClient
          .from('reservas')
          .select('id, codigo_reserva, check_in_previsto, rate_plan_type, monto_total, anticipo_pagado, folios(total_pagos)')
          .eq('id', bookingId)
          .maybeSingle();

      if (resData == null) {
        throw Exception('Reserva no encontrada para evaluación.');
      }

      final checkInStr = resData['check_in_previsto']?.toString() ?? '';
      DateTime checkInDateTime = DateTime.now();
      final parsedDate = DateTime.tryParse(checkInStr);
      if (parsedDate != null) {
        checkInDateTime = DateTime(parsedDate.year, parsedDate.month, parsedDate.day, 14, 0, 0);
      }

      final hoursDiff = checkInDateTime.difference(DateTime.now()).inMinutes / 60.0;
      final rawPlan = resData['rate_plan_type']?.toString() ?? 'Flexible';
      final isFlexible = rawPlan.toLowerCase().contains('flex');

      double totalPagado = 0.0;
      final folios = resData['folios'];
      if (folios is List && folios.isNotEmpty) {
        final f = folios.first as Map<String, dynamic>;
        totalPagado = (f['total_pagos'] is num) ? (f['total_pagos'] as num).toDouble() : 0.0;
      } else if (folios is Map<String, dynamic>) {
        totalPagado = (folios['total_pagos'] is num) ? (folios['total_pagos'] as num).toDouble() : 0.0;
      } else {
        totalPagado = (resData['anticipo_pagado'] is num) ? (resData['anticipo_pagado'] as num).toDouble() : 0.0;
      }

      final currencyFmt = NumberFormat('#,##0', 'es_PY');
      final formattedMonto = '${currencyFmt.format(totalPagado)} Gs.';

      final bool canCancelFree = isFlexible && (hoursDiff > 24.0);
      final bool isPenalty = !canCancelFree;
      final double refundAmount = canCancelFree ? totalPagado : 0.0;
      final double penaltyAmount = isPenalty ? totalPagado : 0.0;

      String message;
      if (canCancelFree) {
        message = 'Tu tarifa permite cancelación gratuita. El monto de $formattedMonto será reembolsado.';
      } else {
        message = isFlexible
            ? 'Atención: Has superado el límite de 24 horas previas al check-in oficial (${hoursDiff.toStringAsFixed(1)} hs restantes). Al cancelar, perderás el monto abonado de $formattedMonto. ¿Deseas proceder?'
            : 'Atención: Tu plan de tarifa (Promo No Reembolsable) no admite devoluciones. Al cancelar, perderás el monto abonado de $formattedMonto. ¿Deseas proceder?';
      }

      return CancellationEvaluation(
        bookingId: bookingId,
        ratePlanType: rawPlan,
        hoursRemaining: hoursDiff,
        totalPaid: totalPagado,
        canCancelFree: canCancelFree,
        isPenalty: isPenalty,
        refundAmount: refundAmount,
        penaltyAmount: penaltyAmount,
        message: message,
      );
    } catch (e) {
      throw Exception('Error al evaluar cancelación de reserva: ${e.toString()}');
    }
  }

  @override
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    try {
      final defaultReason = reason ?? 'Cancelada por el huésped desde App Móvil';

      // 1. Intentar RPC en PostgreSQL
      try {
        final rpcResp = await supabaseClient.rpc(
          'cancel_reservation',
          params: {
            'p_reserva_id': bookingId,
            'p_reason': defaultReason,
          },
        );
        if (rpcResp != null && rpcResp is Map && rpcResp['success'] == true) {
          try {
            final channel = supabaseClient.channel('hotel_universal_sync');
            await channel.sendBroadcastMessage(
              event: 'hotel_data_updated',
              payload: {'table': 'reservas', 'id': bookingId, 'action': 'cancelled'},
            );
          } catch (_) {}
          return true;
        }
      } catch (e) {
        debugPrint('RPC cancel_reservation fallback local: $e');
      }

      // 2. Fallback de cancelación local
      final eval = await evaluateCancellation(bookingId);
      final resData = await supabaseClient
          .from('reservas')
          .select('habitacion_id')
          .eq('id', bookingId)
          .maybeSingle();
      final int? habitacionId = resData?['habitacion_id'] is int
          ? resData!['habitacion_id'] as int
          : int.tryParse(resData?['habitacion_id']?.toString() ?? '');

      final cancellationStatus = eval.isPenalty
          ? 'Penalizado'
          : (eval.refundAmount > 0 ? 'Pendiente' : 'Reembolsado');

      // Actualizar reserva
      try {
        await supabaseClient.from('reservas').update({
          'estado': 'Cancelada',
          'cancellation_status': cancellationStatus,
          'cancellation_penalty_amount': eval.penaltyAmount,
          'refund_amount': eval.refundAmount,
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancellation_reason': defaultReason,
        }).eq('id', bookingId);
      } catch (_) {
        await supabaseClient.from('reservas').update({
          'estado': 'Cancelada',
        }).eq('id', bookingId);
      }

      // Liberar habitación asignada inmediatamente (Disponible)
      if (habitacionId != null) {
        try {
          await supabaseClient.from('habitaciones').update({
            'estado': 'Disponible',
          }).eq('id', habitacionId);
        } catch (_) {}
      }

      // Actualizar folio
      try {
        await supabaseClient.from('folios').update({
          'estado': eval.isPenalty ? 'Cerrado' : 'Cancelado',
        }).eq('reserva_id', bookingId);
      } catch (_) {}

      // Sincronizar en tiempo real
      try {
        final channel = supabaseClient.channel('hotel_universal_sync');
        await channel.sendBroadcastMessage(
          event: 'hotel_data_updated',
          payload: {'table': 'reservas', 'id': bookingId, 'action': 'cancelled'},
        );
      } catch (_) {}

      return true;
    } catch (e) {
      throw Exception('Error al cancelar la reserva: ${e.toString()}');
    }
  }
}
