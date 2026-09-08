import 'package:fpdart/fpdart.dart';
import 'package:trekos_m_hotel/core/error/failures.dart';
import 'package:trekos_m_hotel/features/hotel_search/data/datasources/hotel_remote_data_source.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/cancellation_evaluation.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/repository/hotel_repository.dart';

class HotelRepositoryImpl implements HotelRepository {
  final HotelRemoteDataSource remoteDataSource;

  HotelRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<Room>>> getRooms() async {
    try {
      final rooms = await remoteDataSource.getRooms();
      return right(rooms);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Booking>>> getGuestBookings(String guestId) async {
    try {
      final bookings = await remoteDataSource.getGuestBookings(guestId);
      return right(bookings);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Booking>> createBooking({
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
      final booking = await remoteDataSource.createBooking(
        habitacionId: habitacionId,
        guestId: guestId,
        checkIn: checkIn,
        checkOut: checkOut,
        montoTotal: montoTotal,
        cantidadHuespedes: cantidadHuespedes,
        acompanantes: acompanantes,
        ratePlanType: ratePlanType,
      );
      return right(booking);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CancellationEvaluation>> evaluateCancellation(String bookingId) async {
    try {
      final result = await remoteDataSource.evaluateCancellation(bookingId);
      return right(result);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> cancelBooking(String bookingId, {String? reason}) async {
    try {
      final success = await remoteDataSource.cancelBooking(bookingId, reason: reason);
      return right(success);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> registerFolioPayment({
    required String folioId,
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? reference,
    double discountAmount = 0.0,
    String? couponCode,
  }) async {
    try {
      final success = await remoteDataSource.registerFolioPayment(
        folioId: folioId,
        bookingId: bookingId,
        amount: amount,
        paymentMethod: paymentMethod,
        reference: reference,
        discountAmount: discountAmount,
        couponCode: couponCode,
      );
      return right(success);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
