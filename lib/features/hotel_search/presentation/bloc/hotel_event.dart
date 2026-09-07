import 'package:equatable/equatable.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/filter_criteria.dart';

abstract class HotelEvent extends Equatable {
  const HotelEvent();

  @override
  List<Object?> get props => [];
}

class HotelFetchRooms extends HotelEvent {
  final bool isSilent;
  const HotelFetchRooms({this.isSilent = false});

  @override
  List<Object?> get props => [isSilent];
}

class HotelSearchQueryChanged extends HotelEvent {
  final String query;
  const HotelSearchQueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class HotelFilterCategoryChanged extends HotelEvent {
  final String category;
  const HotelFilterCategoryChanged(this.category);

  @override
  List<Object?> get props => [category];
}

class HotelAdvancedFilterChanged extends HotelEvent {
  final AdvancedFilterCriteria criteria;
  const HotelAdvancedFilterChanged(this.criteria);

  @override
  List<Object?> get props => [criteria];
}

class HotelResetFilters extends HotelEvent {}

class HotelFetchGuestBookings extends HotelEvent {
  final String guestId;
  final bool isSilent;
  const HotelFetchGuestBookings(this.guestId, {this.isSilent = false});

  @override
  List<Object?> get props => [guestId, isSilent];
}

class HotelCreateBookingRequested extends HotelEvent {
  final int habitacionId;
  final String guestId;
  final DateTime checkIn;
  final DateTime checkOut;
  final double montoTotal;
  final int cantidadHuespedes;
  final List<CompanionGuest> acompanantes;

  const HotelCreateBookingRequested({
    required this.habitacionId,
    required this.guestId,
    required this.checkIn,
    required this.checkOut,
    required this.montoTotal,
    required this.cantidadHuespedes,
    this.acompanantes = const [],
  });

  @override
  List<Object?> get props => [
        habitacionId,
        guestId,
        checkIn,
        checkOut,
        montoTotal,
        cantidadHuespedes,
        acompanantes,
      ];
}

class HotelRegisterPaymentRequested extends HotelEvent {
  final String folioId;
  final String bookingId;
  final double amount;
  final String paymentMethod;
  final String? reference;
  final String guestId;

  const HotelRegisterPaymentRequested({
    required this.folioId,
    required this.bookingId,
    required this.amount,
    required this.paymentMethod,
    this.reference,
    required this.guestId,
  });

  @override
  List<Object?> get props => [
        folioId,
        bookingId,
        amount,
        paymentMethod,
        reference,
        guestId,
      ];
}
