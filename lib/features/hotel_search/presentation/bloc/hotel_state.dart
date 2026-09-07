import 'package:equatable/equatable.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/filter_criteria.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';

enum HotelStatus { initial, loading, success, error }

class HotelState extends Equatable {
  final HotelStatus status;
  final List<Room> rooms;
  final List<Room> filteredRooms;
  final String selectedFilter;
  final String searchQuery;
  final AdvancedFilterCriteria advancedFilters;
  final List<Booking> guestBookings;
  final bool isBookingsLoading;
  final String? errorMessage;
  final String? bookingSuccessCode;
  final Booking? createdBooking;
  final bool isSubmittingBooking;
  final bool isSubmittingPayment;
  final bool? paymentSuccess;
  final String? paymentErrorMessage;

  const HotelState({
    this.status = HotelStatus.initial,
    this.rooms = const [],
    this.filteredRooms = const [],
    this.selectedFilter = 'Todas',
    this.searchQuery = '',
    this.advancedFilters = const AdvancedFilterCriteria(),
    this.guestBookings = const [],
    this.isBookingsLoading = false,
    this.errorMessage,
    this.bookingSuccessCode,
    this.createdBooking,
    this.isSubmittingBooking = false,
    this.isSubmittingPayment = false,
    this.paymentSuccess,
    this.paymentErrorMessage,
  });

  HotelState copyWith({
    HotelStatus? status,
    List<Room>? rooms,
    List<Room>? filteredRooms,
    String? selectedFilter,
    String? searchQuery,
    AdvancedFilterCriteria? advancedFilters,
    List<Booking>? guestBookings,
    bool? isBookingsLoading,
    String? errorMessage,
    String? bookingSuccessCode,
    Booking? createdBooking,
    bool? isSubmittingBooking,
    bool? isSubmittingPayment,
    bool? paymentSuccess,
    String? paymentErrorMessage,
  }) {
    return HotelState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      filteredRooms: filteredRooms ?? this.filteredRooms,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      advancedFilters: advancedFilters ?? this.advancedFilters,
      guestBookings: guestBookings ?? this.guestBookings,
      isBookingsLoading: isBookingsLoading ?? this.isBookingsLoading,
      errorMessage: errorMessage,
      bookingSuccessCode: bookingSuccessCode,
      createdBooking: createdBooking ?? this.createdBooking,
      isSubmittingBooking: isSubmittingBooking ?? this.isSubmittingBooking,
      isSubmittingPayment: isSubmittingPayment ?? this.isSubmittingPayment,
      paymentSuccess: paymentSuccess ?? this.paymentSuccess,
      paymentErrorMessage: paymentErrorMessage ?? this.paymentErrorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        rooms,
        filteredRooms,
        selectedFilter,
        searchQuery,
        advancedFilters,
        guestBookings,
        isBookingsLoading,
        errorMessage,
        bookingSuccessCode,
        createdBooking,
        isSubmittingBooking,
        isSubmittingPayment,
        paymentSuccess,
        paymentErrorMessage,
      ];
}
