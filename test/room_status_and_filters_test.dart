import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';
import 'package:trekos_m_hotel/core/error/failures.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/repository/hotel_repository.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';

class FakeHotelRepository implements HotelRepository {
  final List<Room> rooms;
  FakeHotelRepository(this.rooms);

  @override
  Future<Either<Failure, List<Room>>> getRooms() async => Right(rooms);

  @override
  Future<Either<Failure, List<Booking>>> getGuestBookings(String guestId) async =>
      const Right([]);

  @override
  Future<Either<Failure, Booking>> createBooking({
    required int habitacionId,
    required String guestId,
    required DateTime checkIn,
    required DateTime checkOut,
    required double montoTotal,
    required int cantidadHuespedes,
    List<CompanionGuest> acompanantes = const [],
  }) async =>
      Right(Booking(
        id: '1',
        codigoReserva: 'BOOK-123',
        guestId: guestId,
        habitacionId: habitacionId,
        habitacionNumero: '101',
        habitacionTipo: 'Standard Single',
        checkInPrevisto: checkIn.toIso8601String(),
        checkOutPrevisto: checkOut.toIso8601String(),
        cantidadHuespedes: cantidadHuespedes,
        montoTotal: montoTotal,
        estado: 'Confirmada',
        canalVenta: 'App Móvil',
        folioId: 'folio-123',
        folioSaldoPendiente: montoTotal,
        folioTotalPagos: 0.0,
        folioEstado: 'Abierto',
      ));

  @override
  Future<Either<Failure, bool>> registerFolioPayment({
    required String folioId,
    required String bookingId,
    required double amount,
    required String paymentMethod,
    String? reference,
    double discountAmount = 0.0,
    String? couponCode,
  }) async =>
      const Right(true);
}

Room createRoom({
  required int id,
  required String numero,
  required String estado,
  required double precioBase,
}) {
  return Room(
    id: id,
    numero: numero,
    tipoId: 1,
    tipoNombre: 'Standard Single',
    tipoDescripcion: 'Habitación estándar con wifi y aire',
    capacidad: 1,
    precioBase: precioBase,
    piso: 1,
    estado: estado,
    caracteristicas: const {'wifi': true, 'ac': true},
  );
}

void main() {
  group('Room.estadoPublico Tests', () {
    test('Disponible retorna "Disponible"', () {
      final room = createRoom(id: 1, numero: '101', estado: 'disponible', precioBase: 100000);
      expect(room.estadoPublico, equals('Disponible'));
      expect(room.isAvailableForGuest, isTrue);
    });

    test('Ocupada o Reservada retorna "Ocupada"', () {
      final roomOcupada = createRoom(id: 2, numero: '102', estado: 'ocupada', precioBase: 100000);
      final roomOcupado = createRoom(id: 3, numero: '103', estado: 'ocupado', precioBase: 100000);
      final roomReservada = createRoom(id: 4, numero: '104', estado: 'reservada', precioBase: 100000);
      final roomReservado = createRoom(id: 5, numero: '105', estado: 'reservado', precioBase: 100000);

      expect(roomOcupada.estadoPublico, equals('Ocupada'));
      expect(roomOcupado.estadoPublico, equals('Ocupada'));
      expect(roomReservada.estadoPublico, equals('Ocupada'));
      expect(roomReservado.estadoPublico, equals('Ocupada'));
      expect(roomOcupada.isAvailableForGuest, isFalse);
    });

    test('Estados operativos internos retornan "No disponible"', () {
      final estadosInternos = [
        'Check-out pendiente',
        'Sucia',
        'En limpieza',
        'Inspección',
        'mantenimiento',
        'En mantenimiento',
        'Bloqueada',
        'Fuera de servicio',
      ];

      for (var i = 0; i < estadosInternos.length; i++) {
        final room = createRoom(id: 10 + i, numero: '20$i', estado: estadosInternos[i], precioBase: 150000);
        expect(room.estadoPublico, equals('No disponible'),
            reason: 'El estado crudo "${estadosInternos[i]}" debe mostrarse como "No disponible"');
        expect(room.isAvailableForGuest, isFalse);
      }
    });
  });

  group('HotelBloc Filters and Sorting Tests', () {
    late FakeHotelRepository repository;
    late List<Room> mockRooms;

    setUp(() {
      mockRooms = [
        createRoom(id: 1, numero: '101', estado: 'disponible', precioBase: 250000),
        createRoom(id: 2, numero: '102', estado: 'ocupada', precioBase: 180000),
        createRoom(id: 3, numero: '103', estado: 'En limpieza', precioBase: 300000),
        createRoom(id: 4, numero: '104', estado: 'disponible', precioBase: 150000),
        createRoom(id: 5, numero: '105', estado: 'Bloqueada', precioBase: 400000),
      ];
      repository = FakeHotelRepository(mockRooms);
    });

    test('Filtro "Disponible" filtra solo habitaciones disponibles', () async {
      final bloc = HotelBloc(hotelRepository: repository);
      bloc.add(HotelFetchRooms());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const HotelFilterCategoryChanged('Disponible'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.filteredRooms.length, equals(2));
      expect(bloc.state.filteredRooms.every((r) => r.isAvailableForGuest), isTrue);

      await bloc.close();
    });

    test('Filtro "Ocupado" filtra solo habitaciones ocupadas', () async {
      final bloc = HotelBloc(hotelRepository: repository);
      bloc.add(HotelFetchRooms());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const HotelFilterCategoryChanged('Ocupado'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.filteredRooms.length, equals(1));
      expect(bloc.state.filteredRooms.first.numero, equals('102'));
      expect(bloc.state.filteredRooms.first.estadoPublico, equals('Ocupada'));

      await bloc.close();
    });

    test('Filtro "Simple" filtra habitaciones Single/Simple', () async {
      final bloc = HotelBloc(hotelRepository: repository);
      bloc.add(HotelFetchRooms());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const HotelFilterCategoryChanged('Simple'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.filteredRooms.isNotEmpty, isTrue);
      expect(bloc.state.filteredRooms.every((r) => r.tipoNombre.toLowerCase().contains('single')), isTrue);

      await bloc.close();
    });

    test('Filtro "Doble" filtra habitaciones Dobles', () async {
      final customRooms = [
        createRoom(id: 1, numero: '101', estado: 'disponible', precioBase: 250000),
        Room(
          id: 2,
          numero: '102',
          tipoId: 2,
          tipoNombre: 'Doble Superior',
          tipoDescripcion: 'Habitación doble',
          capacidad: 2,
          precioBase: 200000,
          piso: 1,
          estado: 'disponible',
          caracteristicas: const {},
        ),
      ];
      final customRepo = FakeHotelRepository(customRooms);
      final bloc = HotelBloc(hotelRepository: customRepo);
      bloc.add(HotelFetchRooms());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const HotelFilterCategoryChanged('Doble'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.filteredRooms.length, equals(1));
      expect(bloc.state.filteredRooms.first.numero, equals('102'));

      await bloc.close();
    });

    test('Filtro "Suite" filtra suites', () async {
      final customRooms = [
        createRoom(id: 1, numero: '101', estado: 'disponible', precioBase: 250000),
        Room(
          id: 3,
          numero: '301',
          tipoId: 3,
          tipoNombre: 'Suite Presidencial UTCD',
          tipoDescripcion: 'Suite de lujo',
          capacidad: 4,
          precioBase: 650000,
          piso: 3,
          estado: 'disponible',
          caracteristicas: const {},
        ),
      ];
      final customRepo = FakeHotelRepository(customRooms);
      final bloc = HotelBloc(hotelRepository: customRepo);
      bloc.add(HotelFetchRooms());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const HotelFilterCategoryChanged('Suite'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.filteredRooms.length, equals(1));
      expect(bloc.state.filteredRooms.first.numero, equals('301'));

      await bloc.close();
    });

    test('Filtro "Precio Más Bajo" ordena ascendentemente por precio', () async {
      final bloc = HotelBloc(hotelRepository: repository);
      bloc.add(HotelFetchRooms());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const HotelFilterCategoryChanged('Precio Más Bajo'));
      await Future.delayed(const Duration(milliseconds: 50));

      final prices = bloc.state.filteredRooms.map((r) => r.precioBase).toList();
      expect(prices, equals([150000, 180000, 250000, 300000, 400000]));

      await bloc.close();
    });

    test('Filtro "Más Alto" ordena descendentemente por precio', () async {
      final bloc = HotelBloc(hotelRepository: repository);
      bloc.add(HotelFetchRooms());
      await Future.delayed(const Duration(milliseconds: 50));

      bloc.add(const HotelFilterCategoryChanged('Más Alto'));
      await Future.delayed(const Duration(milliseconds: 50));

      final prices = bloc.state.filteredRooms.map((r) => r.precioBase).toList();
      expect(prices, equals([400000, 300000, 250000, 180000, 150000]));

      await bloc.close();
    });
  });

  group('Room.textoDisponibilidad Tests (Tarea 1)', () {
    test('Habitación disponible retorna "Disponible ahora"', () {
      final room = createRoom(id: 1, numero: '101', estado: 'disponible', precioBase: 200000);
      expect(room.textoDisponibilidad, equals('Disponible ahora'));
    });

    test('Habitación ocupada con fecha fija retorna "Disponible desde el dd/MM/yyyy"', () {
      final now = DateTime.now();
      final fechaCheckout = DateTime(now.year, now.month, now.day).add(const Duration(days: 3));
      final formattedExpected = DateFormat('dd/MM/yyyy').format(fechaCheckout);
      final room = Room(
        id: 2,
        numero: '102',
        tipoId: 1,
        tipoNombre: 'Standard Single',
        tipoDescripcion: 'Descripción',
        capacidad: 1,
        precioBase: 200000,
        piso: 1,
        estado: 'ocupada',
        caracteristicas: const {},
        fechaDisponibleDesde: fechaCheckout,
      );

      expect(room.textoDisponibilidad, equals('Disponible desde el $formattedExpected'));
    });

    test('Habitación no disponible por mantenimiento retorna "No disponible"', () {
      final room = createRoom(id: 3, numero: '103', estado: 'mantenimiento', precioBase: 200000);
      expect(room.textoDisponibilidad, equals('No disponible'));
    });
  });

  group('Booking Desglose de Gastos Tests (Tarea 2)', () {
    test('Calcula noches, tarifaPorNoche, IVA10 y gran total correctamente', () {
      const booking = Booking(
        id: '1',
        codigoReserva: 'RES-001',
        guestId: 'usr-1',
        habitacionId: 101,
        habitacionNumero: '101',
        habitacionTipo: 'Standard Single',
        checkInPrevisto: '2026-09-01',
        checkOutPrevisto: '2026-09-04',
        cantidadHuespedes: 1,
        montoTotal: 600000,
        estado: 'Confirmada',
        canalVenta: 'App Móvil',
        folioSaldoPendiente: 600000,
        folioTotalPagos: 0,
        folioEstado: 'Abierto',
        totalConsumos: 50000,
        totalServicios: 30000,
        totalCargos: 20000,
      );

      expect(booking.noches, equals(3));
      expect(booking.tarifaPorNoche, equals(200000));
      expect(booking.iva10, closeTo(600000 / 11, 0.1));
      expect(booking.granTotalGastos, equals(700000));
    });

    test('Instancia de Booking con campos nulos o por defecto no crashea en props ni Equatable', () {
      const bookingDefault = Booking(
        id: '2',
        codigoReserva: 'RES-002',
        guestId: 'usr-2',
        habitacionId: 102,
        habitacionNumero: '102',
        habitacionTipo: 'Doble Superior',
        checkInPrevisto: '2026-09-02',
        checkOutPrevisto: '2026-09-03',
        cantidadHuespedes: 2,
        montoTotal: 300000,
        estado: 'Confirmada',
        canalVenta: 'App Móvil',
        folioEstado: 'Abierto',
      );

      // Verificamos que los getters no lancen Type 'Null' is not a subtype of type 'double'
      expect(bookingDefault.totalConsumos, equals(0.0));
      expect(bookingDefault.totalServicios, equals(0.0));
      expect(bookingDefault.totalCargos, equals(0.0));
      expect(bookingDefault.folioSaldoPendiente, equals(300000.0));
      expect(bookingDefault.folioTotalPagos, equals(0.0));

      // Verificamos que props no arroje excepciones y que la comparación Equatable funcione
      expect(() => bookingDefault.props, returnsNormally);
      expect(bookingDefault == bookingDefault, isTrue);
    });
  });

  group('Room Smart Availability and nextAvailableDate Tests', () {
    test('Habitación disponible sin reservas tiene nextAvailableDate mañana y isAvailableNow true', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final room = createRoom(id: 10, numero: '110', estado: 'disponible', precioBase: 200000);

      expect(room.isAvailableNow, isTrue);
      expect(room.hasImminentBooking, isFalse);
      expect(room.nextAvailableDate, equals(today.add(const Duration(days: 1))));
      expect(room.textoDisponibilidad, equals('Disponible ahora'));
    });

    test('Habitación disponible con reserva inminente salta colisión y muestra fecha disponible', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final checkoutCollision = today.add(const Duration(days: 3));

      final room = Room(
        id: 11,
        numero: '111',
        tipoId: 1,
        tipoNombre: 'Standard Single',
        tipoDescripcion: 'Descripción',
        capacidad: 1,
        precioBase: 200000,
        piso: 1,
        estado: 'disponible',
        caracteristicas: const {},
        bookedRanges: [
          RoomBookedRange(
            checkIn: tomorrow,
            checkOut: checkoutCollision,
            codigoReserva: 'res-col-1',
          ),
        ],
      );

      // Tiene reserva inminente que bloquea mañana
      expect(room.hasImminentBooking, isTrue);
      expect(room.isAvailableNow, isFalse);
      // nextAvailableDate salta hasta el checkout de la reserva
      expect(room.nextAvailableDate, equals(checkoutCollision));
      expect(room.textoDisponibilidad.startsWith('Disponible desde el '), isTrue);
    });

    test('Habitación ocupada muestra Disponible desde el dd/MM/yyyy', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 4));
      final room = Room(
        id: 12,
        numero: '112',
        tipoId: 1,
        tipoNombre: 'Standard Single',
        tipoDescripcion: 'Descripción',
        capacidad: 1,
        precioBase: 200000,
        piso: 1,
        estado: 'ocupada',
        caracteristicas: const {},
        fechaDisponibleDesde: targetDate,
      );

      expect(room.estadoPublico, equals('Ocupada'));
      expect(room.isAvailableNow, isFalse);
      expect(room.textoDisponibilidad.startsWith('Disponible desde el '), isTrue);
    });
  });
}

