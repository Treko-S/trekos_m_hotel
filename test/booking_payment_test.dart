import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:intl/intl.dart';
import 'package:trekos_m_hotel/core/error/failures.dart';
import 'package:trekos_m_hotel/features/auth/domain/entities/user.dart';
import 'package:trekos_m_hotel/features/auth/domain/repository/auth_repository.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/cancellation_evaluation.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/repository/hotel_repository.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/booking_payment_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/explore_rooms_page.dart';

class MockHotelRepositoryForPayment implements HotelRepository {
  bool paymentCalled = false;
  double? registeredAmount;
  String? registeredMethod;
  List<Booking> mockGuestBookings = [];

  @override
  Future<Either<Failure, List<Room>>> getRooms() async => const Right([]);

  @override
  Future<Either<Failure, List<Booking>>> getGuestBookings(String guestId) async => Right(mockGuestBookings);

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
  }) async =>
      Right(Booking(
        id: '1',
        codigoReserva: 'RES-TEST',
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
        folioId: 'folio-101',
        folioSaldoPendiente: montoTotal,
        folioTotalPagos: 0.0,
        folioEstado: 'Abierto',
        ratePlanType: ratePlanType,
      ));

  @override
  Future<Either<Failure, CancellationEvaluation>> evaluateCancellation(String bookingId) async =>
      Right(CancellationEvaluation(
        bookingId: bookingId,
        ratePlanType: 'Flexible',
        hoursRemaining: 48.0,
        totalPaid: 0.0,
        canCancelFree: true,
        isPenalty: false,
        refundAmount: 0.0,
        penaltyAmount: 0.0,
        message: 'Cancelación gratuita disponible.',
      ));

  @override
  Future<Either<Failure, bool>> cancelBooking(String bookingId, {String? reason}) async =>
      const Right(true);

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
    paymentCalled = true;
    registeredAmount = amount;
    registeredMethod = paymentMethod;
    return const Right(true);
  }
}

class MockAuthRepository implements AuthRepository {
  @override
  Future<Either<Failure, User>> currentUser() async => const Right(
        User(
          id: 'guest-123',
          email: 'test@hotel.com',
          name: 'Carlos Benítez',
          phone: '0981987654',
        ),
      );

  @override
  Future<Either<Failure, User>> loginWithEmailPassword({required String email, required String password}) async =>
      currentUser();

  @override
  Future<Either<Failure, User>> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? documentType,
    String? documentNumber,
    String? nationality,
  }) async =>
      currentUser();

  @override
  Future<Either<Failure, void>> signOut() async => const Right(null);
}

class FakeAuthBloc extends AuthBloc {
  FakeAuthBloc() : super(authRepository: MockAuthRepository()) {
    emit(const AuthSuccess(
      User(
        id: 'guest-123',
        email: 'test@hotel.com',
        name: 'Carlos Benítez',
        phone: '0981987654',
      ),
    ));
  }
}

void main() {
  final testBooking = Booking(
    id: 'b-001',
    codigoReserva: 'RES-998877',
    guestId: 'guest-123',
    habitacionId: 5,
    habitacionNumero: '204',
    habitacionTipo: 'Suite Ejecutiva',
    checkInPrevisto: '2026-10-01',
    checkOutPrevisto: '2026-10-03',
    cantidadHuespedes: 2,
    montoTotal: 500000.0,
    estado: 'Confirmada',
    canalVenta: 'App Móvil',
    folioId: 'folio-555',
    folioSaldoPendiente: 500000.0,
    folioTotalPagos: 0.0,
    folioEstado: 'Abierto',
  );

  Widget createTestWidget({
    required Widget child,
    required HotelBloc hotelBloc,
    AuthBloc? authBloc,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => authBloc ?? FakeAuthBloc()),
        BlocProvider<HotelBloc>.value(value: hotelBloc),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('BookingPaymentPage UI & Flow Tests', () {
    late MockHotelRepositoryForPayment repository;
    late HotelBloc hotelBloc;

    setUp(() {
      repository = MockHotelRepositoryForPayment();
      hotelBloc = HotelBloc(hotelRepository: repository);
    });

    tearDown(() async {
      await hotelBloc.close();
    });

    testWidgets('Renderiza correctamente resumen de reserva y opciones de pago', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          hotelBloc: hotelBloc,
          child: BookingPaymentPage(booking: testBooking),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica código de reserva y habitación
      expect(find.text('RES-998877'), findsOneWidget);
      expect(find.text('Hab. 204'), findsOneWidget);
      expect(find.text('Suite Ejecutiva'), findsOneWidget);

      final currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

      // Verifica monto total y saldo actual
      expect(find.textContaining(currencyFormat.format(500000).trim()), findsWidgets);

      // Verifica los chips de monto
      expect(find.text('Total (100%)'), findsOneWidget);
      expect(find.text('50% Anticipo'), findsOneWidget);
      expect(find.text('20% Mínimo'), findsOneWidget);
      expect(find.text('Otro Monto (X)'), findsOneWidget);

      // Verifica métodos de pago
      expect(find.text('Tarjeta'), findsOneWidget);
      expect(find.text('SIPAP'), findsOneWidget);
      expect(find.text('Billetera'), findsOneWidget);

      // Verifica aviso demostrativo
      expect(find.textContaining('Modo Demostración Activo'), findsOneWidget);

      // Verifica botón principal de abono
      expect(find.textContaining('Abonar'), findsWidgets);
    });

    testWidgets('Selección de 50% anticipo actualiza monto y saldo restante', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          hotelBloc: hotelBloc,
          child: BookingPaymentPage(booking: testBooking),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap en 50% Anticipo
      await tester.tap(find.text('50% Anticipo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

      // 50% de 500.000 es 250.000 Gs.
      expect(find.textContaining(currencyFormat.format(250000).trim()), findsWidgets);
    });

    testWidgets('Cambio a Transferencia SIPAP muestra cuenta oficial y campos de referencia', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          hotelBloc: hotelBloc,
          child: BookingPaymentPage(booking: testBooking),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap en método SIPAP
      await tester.tap(find.text('SIPAP'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verifica cuenta bancaria oficial del hotel
      expect(find.text('Cuenta Oficial Hotel Trekos M'), findsOneWidget);
      expect(find.text('01-2345678-01'), findsOneWidget);
      expect(find.text('Banco Continental S.A.E.C.A.'), findsOneWidget);
      expect(find.text('Número de Operación / Comprobante SIPAP'), findsOneWidget);
    });

    testWidgets('Cambio a Billetera muestra línea comercial de giro', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          hotelBloc: hotelBloc,
          child: BookingPaymentPage(booking: testBooking),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap en Billetera
      await tester.tap(find.text('Billetera'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Línea Comercial Hotel: 0981 123 456'), findsOneWidget);
      expect(find.text('Proveedor de Billetera'), findsOneWidget);
      expect(find.text('Código o N° de Transacción'), findsOneWidget);
    });

    testWidgets('Zero Overflow Guarantee en pantallas estrechas de 340px', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool hasOverflow = false;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('A RenderFlex overflowed') ||
            details.toString().contains('OVERFLOWED')) {
          hasOverflow = true;
        }
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        createTestWidget(
          hotelBloc: hotelBloc,
          child: BookingPaymentPage(booking: testBooking),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasOverflow, isFalse);
    });

    testWidgets('Modal de Confirmación de Reserva no genera RenderFlex overflow en pantalla de 320px', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool hasOverflow = false;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('A RenderFlex overflowed') ||
            details.toString().contains('OVERFLOWED')) {
          hasOverflow = true;
        }
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => Dialog(
                      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      backgroundColor: Colors.white,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 38),
                              ),
                              const SizedBox(height: 14),
                              const Text('¡Reserva Confirmada!'),
                              const SizedBox(height: 4),
                              const Text('Código: RES-51794231'),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Flexible(
                                          child: Text('Habitación:', style: TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '101 (Habitacion Standard Single)',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Flexible(
                                          child: Text('Estadía:', style: TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '05/09/2026 al 07/09/2026',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Flexible(
                                          child: Text('Total Estadía:', style: TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text('360.000 Gs.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(hasOverflow, isFalse);
      expect(find.text('¡Reserva Confirmada!'), findsOneWidget);
      expect(find.text('101 (Habitacion Standard Single)'), findsOneWidget);
    });

    testWidgets('Modal Preventivo de Confirmación de Fechas no genera RenderFlex overflow en pantalla de 320px', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool hasOverflow = false;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('A RenderFlex overflowed') ||
            details.toString().contains('OVERFLOWED')) {
          hasOverflow = true;
        }
        originalOnError?.call(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => Dialog(
                      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      backgroundColor: Colors.white,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.event_available_rounded,
                                  color: Color(0xFFD97706),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text('¿Confirmas las fechas?'),
                              const SizedBox(height: 6),
                              const Text('Verifica que las fechas de estadía sean las deseadas antes de generar tu reserva:'),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Flexible(child: Text('Check-in:')),
                                        Flexible(child: Text('05/09/2026 (14:00 hs)')),
                                      ],
                                    ),
                                    const Divider(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Flexible(child: Text('Check-out:')),
                                        Flexible(child: Text('07/09/2026 (11:00 hs)')),
                                      ],
                                    ),
                                    const Divider(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Flexible(child: Text('Duración:')),
                                        Flexible(child: Text('2 noches')),
                                      ],
                                    ),
                                    const Divider(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: const [
                                        Flexible(child: Text('Monto Estimado:')),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('360.000 Gs.'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  child: const Text('Sí, Fechas Correctas'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  child: const Text('Modificar Fechas'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open Pre-Confirm'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Pre-Confirm'));
      await tester.pumpAndSettle();

      expect(hasOverflow, isFalse);
      expect(find.text('¿Confirmas las fechas?'), findsOneWidget);
      expect(find.text('Sí, Fechas Correctas'), findsOneWidget);
      expect(find.text('Modificar Fechas'), findsOneWidget);
    });

    testWidgets('Mis Reservas: Tarjeta de reserva oculta detalles por defecto y los muestra al presionar Ver detalles', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool hasOverflow = false;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.toString().contains('A RenderFlex overflowed') ||
            details.toString().contains('OVERFLOWED')) {
          hasOverflow = true;
        }
        originalOnError?.call(details);
      };

      final currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: BookingCardItem(
                  booking: testBooking,
                  currencyFormat: currencyFormat,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasOverflow, isFalse);
      expect(find.text('RES-998877'), findsOneWidget);
      expect(find.text('Habitación 204 • Suite Ejecutiva'), findsOneWidget);
      expect(find.text('Ver detalles'), findsOneWidget);

      // Desglose detallado está oculto inicialmente (Cero saturación visual)
      expect(find.text('Detalle de Gastos'), findsNothing);
      expect(find.text('Alojamiento'), findsNothing);

      // Tocar Ver detalles
      await tester.tap(find.text('Ver detalles'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasOverflow, isFalse);
      expect(find.text('Ocultar detalles'), findsOneWidget);
      expect(find.text('Detalle de Gastos'), findsOneWidget);
      expect(find.text('Alojamiento'), findsOneWidget);
      expect(find.text('Abonar / Pagar Saldo'), findsOneWidget);

      // Tocar Ocultar detalles
      await tester.tap(find.text('Ocultar detalles'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(hasOverflow, isFalse);
      expect(find.text('Ver detalles'), findsOneWidget);
      expect(find.text('Detalle de Gastos'), findsNothing);
      expect(find.text('Alojamiento'), findsNothing);
    });
  });

  group('HotelBloc Payment Event Tests', () {
    test('HotelRegisterPaymentRequested actualiza folio y emite paymentSuccess', () async {
      final repository = MockHotelRepositoryForPayment();
      final bloc = HotelBloc(hotelRepository: repository);

      bloc.add(const HotelRegisterPaymentRequested(
        folioId: 'folio-555',
        bookingId: 'b-001',
        amount: 250000.0,
        paymentMethod: 'Transferencia SIPAP',
        reference: 'Ref: 123456',
        guestId: 'guest-123',
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(repository.paymentCalled, isTrue);
      expect(repository.registeredAmount, equals(250000.0));
      expect(repository.registeredMethod, equals('Transferencia SIPAP'));
      expect(bloc.state.paymentSuccess, isTrue);
      expect(bloc.state.isSubmittingPayment, isFalse);

      await bloc.close();
    });
  });
}
