import 'package:fpdart/fpdart.dart';
import 'package:trekos_m_hotel/core/error/failures.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';

import 'package:trekos_m_hotel/features/hotel_search/domain/entities/cancellation_evaluation.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';

abstract class HotelRepository {
  Future<Either<Failure, List<Room>>> getRooms();
  Future<Either<Failure, List<Booking>>> getGuestBookings(String guestId);
  Future<Either<Failure, Booking>> createBooking({
    required int habitacionId,
    required String guestId,
    required DateTime checkIn,
    required DateTime checkOut,
    required double montoTotal,
    required int cantidadHuespedes,
    List<CompanionGuest> acompanantes = const [],
    String ratePlanType = 'Flexible',
  });
  Future<Either<Failure, CancellationEvaluation>> evaluateCancellation(String bookingId);
  Future<Either<Failure, bool>> cancelBooking(String bookingId, {String? reason});
  Future<Either<Failure, bool>> registerFolioPayment({
    required String folioId,
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? reference,
    double discountAmount = 0.0,
    String? couponCode,
  });
}
