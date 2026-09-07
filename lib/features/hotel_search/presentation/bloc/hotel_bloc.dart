import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/filter_criteria.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/repository/hotel_repository.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_state.dart';

class HotelBloc extends Bloc<HotelEvent, HotelState> {
  final HotelRepository hotelRepository;
  Timer? _debounceTimer;
  Timer? _autoSyncTimer;

  HotelBloc({required this.hotelRepository}) : super(const HotelState()) {
    on<HotelFetchRooms>(_onFetchRooms);
    on<HotelSearchQueryChanged>(_onSearchQueryChanged);
    on<HotelFilterCategoryChanged>(_onFilterCategoryChanged);
    on<HotelAdvancedFilterChanged>(_onAdvancedFilterChanged);
    on<HotelResetFilters>(_onResetFilters);
    on<HotelFetchGuestBookings>(_onFetchGuestBookings);
    on<HotelCreateBookingRequested>(_onCreateBookingRequested);
    on<HotelRegisterPaymentRequested>(_onRegisterPaymentRequested);

    // Heartbeat auto-sync global a nivel de BLoC cada 3 segundos (inmune a navegación de pantallas)
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      add(const HotelFetchRooms(isSilent: true));
    });
  }

  @override
  Future<void> close() {
    _autoSyncTimer?.cancel();
    _debounceTimer?.cancel();
    return super.close();
  }

  Future<void> _onFetchRooms(
    HotelFetchRooms event,
    Emitter<HotelState> emit,
  ) async {
    if (!event.isSilent && state.rooms.isEmpty) {
      emit(state.copyWith(status: HotelStatus.loading, errorMessage: null));
    }

    final result = await hotelRepository.getRooms();

    result.fold(
      (failure) {
        if (!event.isSilent) {
          emit(state.copyWith(
            status: HotelStatus.error,
            errorMessage: failure.message,
          ));
        }
      },
      (rooms) {
        final filtered = _applyFilter(rooms, state.selectedFilter, state.searchQuery, state.advancedFilters);
        emit(state.copyWith(
          status: HotelStatus.success,
          rooms: rooms,
          filteredRooms: filtered,
        ));
      },
    );
  }

  void _onSearchQueryChanged(
    HotelSearchQueryChanged event,
    Emitter<HotelState> emit,
  ) {
    final sanitizedQuery = event.query.trim().toLowerCase();
    
    final filtered = _applyFilter(state.rooms, state.selectedFilter, sanitizedQuery, state.advancedFilters);
    emit(state.copyWith(
      searchQuery: sanitizedQuery,
      filteredRooms: filtered,
    ));
  }

  void _onFilterCategoryChanged(
    HotelFilterCategoryChanged event,
    Emitter<HotelState> emit,
  ) {
    final newCategory = (state.selectedFilter == event.category && event.category != 'Todas')
        ? 'Todas'
        : event.category;
    final filtered = _applyFilter(state.rooms, newCategory, state.searchQuery, state.advancedFilters);
    emit(state.copyWith(
      selectedFilter: newCategory,
      filteredRooms: filtered,
    ));
  }

  void _onAdvancedFilterChanged(
    HotelAdvancedFilterChanged event,
    Emitter<HotelState> emit,
  ) {
    final filtered = _applyFilter(state.rooms, state.selectedFilter, state.searchQuery, event.criteria);
    emit(state.copyWith(
      advancedFilters: event.criteria,
      filteredRooms: filtered,
    ));
  }

  void _onResetFilters(
    HotelResetFilters event,
    Emitter<HotelState> emit,
  ) {
    const defaultFilters = AdvancedFilterCriteria();
    final filtered = _applyFilter(state.rooms, 'Todas', '', defaultFilters);
    emit(state.copyWith(
      selectedFilter: 'Todas',
      searchQuery: '',
      advancedFilters: defaultFilters,
      filteredRooms: filtered,
    ));
  }

  Future<void> _onFetchGuestBookings(
    HotelFetchGuestBookings event,
    Emitter<HotelState> emit,
  ) async {
    if (event.guestId.isEmpty) return;

    try {
      if (!event.isSilent && state.guestBookings.isEmpty) {
        emit(state.copyWith(isBookingsLoading: true));
      }

      final result = await hotelRepository.getGuestBookings(event.guestId);

      result.fold(
        (failure) {
          if (!event.isSilent) {
            emit(state.copyWith(
              isBookingsLoading: false,
              errorMessage: failure.message,
            ));
          }
        },
        (bookings) => emit(state.copyWith(
          isBookingsLoading: false,
          guestBookings: bookings,
        )),
      );
    } catch (e) {
      if (!event.isSilent) {
        emit(state.copyWith(
          isBookingsLoading: false,
          errorMessage: 'Error al procesar reservas: ${e.toString()}',
        ));
      }
    }
  }

  Future<void> _onCreateBookingRequested(
    HotelCreateBookingRequested event,
    Emitter<HotelState> emit,
  ) async {
    emit(state.copyWith(
      isSubmittingBooking: true,
      bookingSuccessCode: null,
      errorMessage: null,
    ));

    final result = await hotelRepository.createBooking(
      habitacionId: event.habitacionId,
      guestId: event.guestId,
      checkIn: event.checkIn,
      checkOut: event.checkOut,
      montoTotal: event.montoTotal,
      cantidadHuespedes: event.cantidadHuespedes,
      acompanantes: event.acompanantes,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        isSubmittingBooking: false,
        errorMessage: failure.message,
      )),
      (booking) {
        emit(state.copyWith(
          isSubmittingBooking: false,
          bookingSuccessCode: booking.codigoReserva,
          createdBooking: booking,
        ));
        add(HotelFetchRooms());
        add(HotelFetchGuestBookings(event.guestId));
      },
    );
  }

  Future<void> _onRegisterPaymentRequested(
    HotelRegisterPaymentRequested event,
    Emitter<HotelState> emit,
  ) async {
    emit(state.copyWith(
      isSubmittingPayment: true,
      paymentSuccess: null,
      paymentErrorMessage: null,
    ));

    final result = await hotelRepository.registerFolioPayment(
      folioId: event.folioId,
      bookingId: event.bookingId,
      amount: event.amount,
      paymentMethod: event.paymentMethod,
      reference: event.reference,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        isSubmittingPayment: false,
        paymentSuccess: false,
        paymentErrorMessage: failure.message,
      )),
      (success) {
        emit(state.copyWith(
          isSubmittingPayment: false,
          paymentSuccess: true,
        ));
        add(HotelFetchGuestBookings(event.guestId));
      },
    );
  }

  List<Room> _applyFilter(
    List<Room> rooms,
    String filter,
    String query,
    AdvancedFilterCriteria adv,
  ) {
    final result = rooms.where((room) {
      // 1. Búsqueda por texto
      final matchesSearch = query.isEmpty ||
          room.numero.toLowerCase().contains(query) ||
          room.tipoNombre.toLowerCase().contains(query) ||
          room.tipoDescripcion.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      // 2. Filtro rápido (tipo de habitación, estado o precio)
      if (filter == 'Simple') {
        final name = room.tipoNombre.toLowerCase();
        final desc = room.tipoDescripcion.toLowerCase();
        if (!name.contains('single') && !name.contains('simple') && !desc.contains('single') && !desc.contains('simple')) {
          return false;
        }
      } else if (filter == 'Doble') {
        final name = room.tipoNombre.toLowerCase();
        final desc = room.tipoDescripcion.toLowerCase();
        if (!name.contains('doble') && !name.contains('double') && !desc.contains('doble') && !desc.contains('double')) {
          return false;
        }
      } else if (filter == 'Suite') {
        final name = room.tipoNombre.toLowerCase();
        final desc = room.tipoDescripcion.toLowerCase();
        if (!name.contains('suite') && !desc.contains('suite')) {
          return false;
        }
      } else if ((filter == 'Disponible' || filter == 'Disponibles') && !room.isAvailableForGuest) {
        return false;
      } else if ((filter == 'Ocupado' || filter == 'Ocupadas') && room.estadoPublico != 'Ocupada') {
        return false;
      } else if (filter == 'No disponible' && room.estadoPublico != 'No disponible') {
        return false;
      }

      // 3. Filtros Avanzados
      // 3.1 Rango de Precio (Desde - Hasta)
      if (room.precioBase < adv.minPrice || room.precioBase > adv.maxPrice) return false;

      // 3.2 Tipo de Habitación
      if (adv.roomType != null && adv.roomType != 'ALL' && adv.roomType!.isNotEmpty) {
        if (!room.tipoNombre.toLowerCase().contains(adv.roomType!.toLowerCase())) {
          return false;
        }
      }

      // 3.3 Capacidad mínima
      if (room.capacidad < adv.minCapacity) return false;

      // 3.4 Piso
      if (adv.floor != null && room.piso != adv.floor) return false;

      // 3.5 Servicios / Amenities
      final desc = room.tipoDescripcion.toLowerCase();
      final cars = room.caracteristicas;

      if (adv.requireAc) {
        final hasAc = (cars['ac'] == true) || desc.contains('aire') || desc.contains('ac');
        if (!hasAc) return false;
      }

      if (adv.requireWifi) {
        final hasWifi = (cars['wifi'] == true) || desc.contains('wifi');
        if (!hasWifi) return false;
      }

      if (adv.requireTv) {
        final hasTv = (cars['tv'] == true) || desc.contains('tv') || desc.contains('cable');
        if (!hasTv) return false;
      }

      if (adv.requireMinibar) {
        final hasMinibar = (cars['minibar'] == true) || desc.contains('frigobar') || desc.contains('minibar');
        if (!hasMinibar) return false;
      }

      if (adv.requireJacuzzi) {
        final hasJacuzzi = desc.contains('jacuzzi') || desc.contains('hidromasaje');
        if (!hasJacuzzi) return false;
      }

      if (adv.requireBalcony) {
        final hasBalcony = desc.contains('balcón') || desc.contains('balcon') || desc.contains('vista');
        if (!hasBalcony) return false;
      }

      return true;
    }).toList();

    // 4. Ordenamiento por precio si el filtro rápido corresponde
    if (filter == 'Precio Más Bajo') {
      result.sort((a, b) => a.precioBase.compareTo(b.precioBase));
    } else if (filter == 'Más Alto' || filter == 'Precio Más Alto') {
      result.sort((a, b) => b.precioBase.compareTo(a.precioBase));
    }

    return result;
  }
}
