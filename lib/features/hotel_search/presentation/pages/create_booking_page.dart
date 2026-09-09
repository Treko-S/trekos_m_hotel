import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/core/services/email_notification_service.dart';
import 'package:trekos_m_hotel/core/services/notification_service.dart';
import 'package:trekos_m_hotel/core/services/hotel_settings_service.dart';
import 'package:trekos_m_hotel/features/auth/domain/entities/user.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_state.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/booking_payment_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/explore_rooms_page.dart';

class CreateBookingPage extends StatefulWidget {
  final Room room;
  final User user;

  const CreateBookingPage({
    super.key,
    required this.room,
    required this.user,
  });

  @override
  State<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends State<CreateBookingPage> {
  late DateTime _checkIn;
  late DateTime _checkOut;
  bool _hasDateCollision = false;

  // Control legal de huéspedes: adultos (mínimo 1) y niños
  int _adultsCount = 1;
  int _childrenCount = 0;
  int get _totalGuests => _adultsCount + _childrenCount;

  // Registro legal obligatorio de huéspedes acompañantes (exigido por ley hotelera cuando total > 1)
  List<CompanionGuest> _companions = [];

  // Datos de registro editables del huésped titular
  late String _guestName;
  late String _guestEmail;
  late String _guestPhone;
  late String _guestDocType;
  late String _guestDocNumber;
  late String _guestNationality;

  final currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);
  final dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Inicializar fechas respetando la disponibilidad real de la habitación
    _checkIn = widget.room.nextAvailableDate;
    var candidateOut = _checkIn.add(const Duration(days: 2));
    if (!widget.room.isDateRangeAvailable(_checkIn, candidateOut)) {
      candidateOut = _checkIn.add(const Duration(days: 1));
    }
    _checkOut = candidateOut;
    _hasDateCollision = !widget.room.isDateRangeAvailable(_checkIn, _checkOut);

    _guestName = widget.user.name.isNotEmpty ? widget.user.name : 'Huésped';
    _guestEmail = widget.user.email;
    _guestPhone = widget.user.phone ?? '';
    _guestDocType = widget.user.documentType ?? 'CI';
    _guestDocNumber = widget.user.documentNumber ?? '';
    _guestNationality = widget.user.nationality ?? 'Paraguaya';
    _syncCompanions();
    _fetchSeasonsAndPlans();
  }

  double _seasonMultiplier = 1.0;
  String? _seasonName;
  List<Map<String, dynamic>> _promoPackages = [];
  Map<String, dynamic>? _selectedPromoPackage;

  List<Map<String, dynamic>> _ratePlans = [
    {
      'code': 'flexible',
      'name': 'Tarifa Flexible Estándar',
      'badge': 'Sin Riesgo',
      'discount': 0,
      'cancellation': 'Cancelación 100% gratuita hasta 24 hs previas al check-in. Máxima flexibilidad.',
    },
    {
      'code': 'promo',
      'name': 'Tarifa Promo No Reembolsable',
      'badge': 'Ahorra 10% 🌟',
      'discount': 10,
      'cancellation': 'Pago anticipado garantizado. No admite reembolso en caso de cancelación o no-show.',
    },
    {
      'code': 'corporativo',
      'name': 'Tarifa Corporativa & Larga Estadía',
      'badge': 'Ahorra 15% 💼',
      'discount': 15,
      'cancellation': 'Tarifa corporativa preferencial aplicable para convenios o estadías superiores a 3 noches.',
    },
  ];

  Future<void> _fetchSeasonsAndPlans() async {
    try {
      final supabase = Supabase.instance.client;
      // 1. Cargar temporadas vigentes para la fecha seleccionada
      final seasonsRes = await supabase.from('temporadas').select();
      if (seasonsRes.isNotEmpty) {
        final checkInStr = DateFormat('yyyy-MM-dd').format(_checkIn);
        for (final s in seasonsRes) {
          final start = s['fecha_inicio']?.toString();
          final end = s['fecha_fin']?.toString();
          if (start != null && end != null) {
            if (checkInStr.compareTo(start) >= 0 && checkInStr.compareTo(end) <= 0) {
              final mult = ((s['multiplicador_tarifa'] ?? s['multiplicador']) as num?)?.toDouble() ?? 1.0;
              if (mounted) {
                setState(() {
                  _seasonMultiplier = mult;
                  _seasonName = s['nombre']?.toString();
                });
              }
              break;
            }
          }
        }
      }

      // 2. Cargar planes de tarifas dinámicos de Supabase Storage
      try {
        final storageData = await supabase.storage.from('hotel-rooms').download('config/rate_plans.json');
        if (storageData.isNotEmpty) {
          final jsonString = utf8.decode(storageData);
          final decoded = jsonDecode(jsonString);
          if (decoded is List && decoded.isNotEmpty) {
            final activePlans = decoded
                .where((p) => p['active'] != false)
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList();
            if (activePlans.isNotEmpty && mounted) {
              setState(() {
                _ratePlans = activePlans;
              });
            }
          }
        }
      } catch (_) {}

      // 3. Cargar paquetes promocionales vinculados al tipo de habitación (Tarea 13)
      final pkgs = await HotelSettingsService.getActivePromotionalPackages(roomTypeId: widget.room.tipoId);
      if (pkgs.isNotEmpty && mounted) {
        setState(() {
          _promoPackages = pkgs;
        });
      }
    } catch (_) {}
  }

  void _syncCompanions() {
    final targetAdults = _adultsCount - 1; // El primer adulto es el huésped titular
    final targetChildren = _childrenCount;

    final currentAdults = _companions.where((c) => c.isAdult).toList();
    final currentChildren = _companions.where((c) => !c.isAdult).toList();

    final updatedAdults = <CompanionGuest>[];
    for (int i = 0; i < targetAdults; i++) {
      if (i < currentAdults.length) {
        updatedAdults.add(currentAdults[i]);
      } else {
        updatedAdults.add(CompanionGuest(
          id: 'comp_adult_${DateTime.now().millisecondsSinceEpoch}_$i',
          isAdult: true,
          relationship: 'Acompañante',
          documentType: 'CI',
          nationality: 'Paraguaya',
        ));
      }
    }

    final updatedChildren = <CompanionGuest>[];
    for (int i = 0; i < targetChildren; i++) {
      if (i < currentChildren.length) {
        updatedChildren.add(currentChildren[i]);
      } else {
        updatedChildren.add(CompanionGuest(
          id: 'comp_child_${DateTime.now().millisecondsSinceEpoch}_$i',
          isAdult: false,
          relationship: 'Hijo/a',
          documentType: 'CI',
          nationality: 'Paraguaya',
        ));
      }
    }

    setState(() {
      _companions = [...updatedAdults, ...updatedChildren];
    });
  }

  String _selectedRatePlan = 'flexible'; // 'flexible' | 'promo' | 'corporativo'

  int get _totalNights {
    final diff = _checkOut.difference(_checkIn).inDays;
    return diff > 0 ? diff : 1;
  }

  double get _nightlyPrice => widget.room.precioBase * _seasonMultiplier;
  double get _basePrice => _nightlyPrice * _totalNights;
  double get _discount {
    final plan = _ratePlans.firstWhere(
      (p) => p['code'] == _selectedRatePlan,
      orElse: () => {'discount': _selectedRatePlan == 'promo' ? 10 : (_selectedRatePlan == 'corporativo' ? 15 : 0)},
    );
    final disc = (plan['discount'] as num?)?.toDouble() ?? 0.0;
    return _basePrice * (disc / 100.0);
  }
  double get _totalPrice {
    if (_selectedPromoPackage != null) {
      final pkgPrice = (_selectedPromoPackage!['package_price'] as num?)?.toDouble() ?? 0.0;
      if (pkgPrice > 0) return pkgPrice;
    }
    return _basePrice - _discount;
  }
  double get _iva10 => _totalPrice / 11;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final coverImage = (room.imagenes.isNotEmpty ? room.imagenes.first : room.imagenCover) ??
        'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800';

    return BlocListener<HotelBloc, HotelState>(
      listener: (context, state) {
        if (state.errorMessage != null && !state.isSubmittingBooking) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.errorMessage!)),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }

        if (state.bookingSuccessCode != null && !state.isSubmittingBooking) {
          if (_selectedPromoPackage != null) {
            _dispatchPackageIncludedServices(state.bookingSuccessCode!, state.createdBooking);
          }
          _showLuxurySuccessDialog(context, state.bookingSuccessCode!, state.createdBooking);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Confirmación de Reserva',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppTheme.navyLuxury,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. TARJETA HERO DE HABITACIÓN
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Foto miniatura y badge
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: Image.network(
                              coverImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppTheme.navyLuxury,
                                child: const Icon(Icons.hotel, color: AppTheme.goldLuxury, size: 40),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.navyLuxury.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              room.tipoNombre,
                              style: const TextStyle(color: AppTheme.goldLuxury, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Detalles
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Habitación ${room.numero}',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navyLuxury,
                                ),
                              ),
                              Text(
                                '${currencyFormat.format(room.precioBase)} Gs. / noche',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.goldLuxury,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            room.tipoDescripcion,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==========================================
              // 2. DATOS DEL HUÉSPED TITULAR
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Huésped Titular',
                      style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openEditGuestModal,
                    icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.primaryBlue),
                    label: const Text(
                      'Editar datos',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.navyLuxury,
                          child: Text(
                            _guestName.isNotEmpty ? _guestName.substring(0, 1).toUpperCase() : 'H',
                            style: const TextStyle(color: AppTheme.goldLuxury, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _guestName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyLuxury),
                              ),
                              Text(
                                _guestEmail,
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.verified, color: AppTheme.goldLuxury, size: 20),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGuestInfoPill(
                            Icons.badge_outlined,
                            'Documento',
                            '$_guestDocType: ${_guestDocNumber.isNotEmpty ? _guestDocNumber : 'No asignado'}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildGuestInfoPill(
                            Icons.phone_outlined,
                            'Teléfono',
                            _guestPhone.isNotEmpty ? _guestPhone : 'No asignado',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildGuestInfoPill(
                      Icons.public_outlined,
                      'Nacionalidad',
                      _guestNationality,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // 3. SELECTOR DE FECHAS DE ESTADÍA Y HUÉSPEDES
              // ==========================================
              Text(
                'Fechas de Estadía',
                style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // Check-in Box
                  Expanded(
                    child: InkWell(
                      onTap: _selectCheckInDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.login_rounded, size: 16, color: Color(0xFF10B981)),
                                SizedBox(width: 6),
                                Text('CHECK-IN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                dateFormat.format(_checkIn),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                              ),
                            ),
                            Text(
                              'Desde ${HotelSettingsService.checkInTime} hs',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Check-out Box
                  Expanded(
                    child: InkWell(
                      onTap: _selectCheckOutDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                                SizedBox(width: 6),
                                Text('CHECK-OUT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                dateFormat.format(_checkOut),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                              ),
                            ),
                            Text(
                              'Hasta ${HotelSettingsService.checkOutTime} hs',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_hasDateCollision) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Conflicto de fechas: La habitación ya se encuentra reservada u ocupada en este rango. Por favor selecciona fechas libres.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (widget.room.bookedRanges.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.event_busy_outlined, size: 14, color: Color(0xFF64748B)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Fechas no disponibles (ya reservadas) para esta habitación:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: widget.room.bookedRanges.map((range) {
                          final start = dateFormat.format(range.checkIn);
                          final end = dateFormat.format(range.checkOut);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              '$start al $end',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Indicador de Duración de Noches
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.nights_stay, size: 18, color: AppTheme.goldLuxury),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Duración: $_totalNights noche${_totalNights > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyLuxury),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Selector Detallado de Huéspedes (Adultos + Niños con Control Legal)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Distribución de Huéspedes',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyLuxury),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _totalGuests >= room.capacidad
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_totalGuests de ${room.capacidad} pers. máx.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _totalGuests >= room.capacidad ? const Color(0xFFD97706) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Adultos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Adultos',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyLuxury),
                              ),
                              Text(
                                'Mayores de 12 años (Mín. 1 legal)',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppTheme.navyLuxury),
                              onPressed: _adultsCount > 1
                                  ? () {
                                      _adultsCount--;
                                      _syncCompanions();
                                    }
                                  : null,
                            ),
                            Text(
                              '$_adultsCount',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyLuxury),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.navyLuxury),
                              onPressed: _totalGuests < room.capacidad
                                  ? () {
                                      _adultsCount++;
                                      _syncCompanions();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Niños
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Niños',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyLuxury),
                              ),
                              Text(
                                'De 0 a 11 años',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 22, color: AppTheme.navyLuxury),
                              onPressed: _childrenCount > 0
                                  ? () {
                                      _childrenCount--;
                                      _syncCompanions();
                                    }
                                  : null,
                            ),
                            Text(
                              '$_childrenCount',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyLuxury),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 22, color: AppTheme.navyLuxury),
                              onPressed: _totalGuests < room.capacidad
                                  ? () {
                                      _childrenCount++;
                                      _syncCompanions();
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (_totalGuests >= room.capacidad) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 15, color: Color(0xFFEA580C)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Capacidad máxima alcanzada (${room.capacidad} personas permitidas por regulación del hotel).',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC2410C)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // 3.1 REGISTRO LEGAL OBLIGATORIO DE ACOMPAÑANTES
              // ==========================================
              _buildCompanionsSection(),

              const SizedBox(height: 24),

              // ==========================================
              // 3.2 PLAN DE TARIFA & POLÍTICAS
              // ==========================================
              _buildRatePlanSelector(),

              const SizedBox(height: 24),

              // ==========================================
              // 4. DESGLOSE DEL PRECIO & FOLIO
              // ==========================================
              Text(
                'Resumen de Liquidación',
                style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _seasonMultiplier != 1.0 && _seasonName != null
                                ? 'Tarifa base (${currencyFormat.format(_nightlyPrice)} Gs. [$_seasonName] x $_totalNights noche${_totalNights > 1 ? 's' : ''})'
                                : 'Tarifa base (${currencyFormat.format(_nightlyPrice)} Gs. x $_totalNights noche${_totalNights > 1 ? 's' : ''})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currencyFormat.format(_basePrice)} Gs.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedPromoPackage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Paquete Promocional: ${_selectedPromoPackage!['name']}',
                              style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: const Text('Todo Incluido (0 Gs. extras)', style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ] else if (_discount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Descuento ${_ratePlans.firstWhere((p) => p['code'] == _selectedRatePlan, orElse: () => {'name': 'Promoción'})['name']}',
                              style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '- ${currencyFormat.format(_discount)} Gs.',
                              style: const TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Liquidación IVA 10% (Incluido)',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currencyFormat.format(_iva10)} Gs.',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Total de Estadía:',
                            style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currencyFormat.format(_totalPrice)} Gs.',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navyLuxury,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Garantía y Folio Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_user_outlined, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Reserva inmediata y confirmada. Puedes abonar en recepción o desde la app.',
                        style: TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ==========================================
              // 5. BOTÓN PRINCIPAL DE CONFIRMACIÓN
              // ==========================================
              BlocBuilder<HotelBloc, HotelState>(
                builder: (context, state) {
                  return SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyLuxury,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: state.isSubmittingBooking ? null : _confirmBooking,
                      child: state.isSubmittingBooking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_circle_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirmar Reserva Ahora',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _selectCheckInDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _checkIn = picked;
        if (_checkOut.isBefore(_checkIn.add(const Duration(days: 1)))) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
        _hasDateCollision = !widget.room.isDateRangeAvailable(_checkIn, _checkOut);
      });
      _fetchSeasonsAndPlans();
      if (_hasDateCollision) {
        _showCollisionSnackBar();
      }
    }
  }

  void _selectCheckOutDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _checkOut = picked;
        _hasDateCollision = !widget.room.isDateRangeAvailable(_checkIn, _checkOut);
      });
      if (_hasDateCollision) {
        _showCollisionSnackBar();
      }
    }
  }

  void _showCollisionSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.event_busy_rounded, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('Las fechas seleccionadas coinciden con una reserva existente. Por favor selecciona fechas libres.'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmBooking() {
    // 1. Validar si el huésped titular aún no cuenta con documento oficial
    if (_guestDocNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Por favor completa el número de documento del titular antes de reservar.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _openEditGuestModal();
      return;
    }

    // 2. Control legal obligatorio de acompañantes si hay más de 1 huésped
    if (_totalGuests > 1) {
      final incompleteIdx = _companions.indexWhere((c) => !c.isComplete);
      if (incompleteIdx != -1) {
        final comp = _companions[incompleteIdx];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Requisito legal: debes registrar los datos oficiales del Acompañante ${incompleteIdx + 1} (${comp.isAdult ? "Adulto" : "Menor"}).',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFC2410C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _openEditCompanionModal(incompleteIdx);
        return;
      }
    }

    // 3. Validación de disponibilidad por fechas y tiempo real (sin colisión)
    if (_hasDateCollision || !widget.room.isDateRangeAvailable(_checkIn, _checkOut)) {
      _showCollisionSnackBar();
      return;
    }

    final currentRooms = context.read<HotelBloc>().state.rooms;
    final matchingRoom = currentRooms.where((r) => r.id == widget.room.id).firstOrNull;
    if (matchingRoom != null) {
      if (!matchingRoom.canBeBooked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Esta habitación no se encuentra habilitada para reservas en este momento.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }

      if (!matchingRoom.isDateRangeAvailable(_checkIn, _checkOut)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.event_busy_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Las fechas seleccionadas acaban de ser reservadas. Por favor selecciona otro rango libre.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    // Validación preventiva de fechas con confirmación explícita del usuario
    _showConfirmBookingDatesDialog();
  }

  void _proceedWithBookingCreation() {
    final selectedPlanObj = _ratePlans.firstWhere(
      (p) => p['code'] == _selectedRatePlan,
      orElse: () => {'name': _selectedRatePlan == 'promo' ? 'No Reembolsable' : (_selectedRatePlan == 'corporativo' ? 'Corporativo' : 'Flexible')},
    );
    String ratePlanString = selectedPlanObj['name']?.toString() ?? (_selectedRatePlan == 'promo' ? 'No Reembolsable' : 'Flexible');
    if (_selectedPromoPackage != null) {
      ratePlanString = '${_selectedPromoPackage!['name']} (Paquete Promocional)';
    }

    context.read<HotelBloc>().add(
          HotelCreateBookingRequested(
            habitacionId: widget.room.id,
            guestId: widget.user.id,
            checkIn: _checkIn,
            checkOut: _checkOut,
            montoTotal: _totalPrice,
            cantidadHuespedes: _totalGuests,
            acompanantes: _companions,
            ratePlanType: ratePlanString,
          ),
        );
  }

  void _showConfirmBookingDatesDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                // Icono superior representativo
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

                // Título
                Text(
                  '¿Confirmas las fechas?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyLuxury,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtítulo explicativo
                Text(
                  'Verifica que las fechas de estadía sean las deseadas antes de generar tu reserva:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjeta Resumen de Fechas
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Check-In
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.login_rounded, size: 16, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text(
                                'Check-in:',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              '${dateFormat.format(_checkIn)} (${HotelSettingsService.checkInTime} hs)',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.navyLuxury),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14, color: Color(0xFFF1F5F9)),

                      // Check-Out
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                              SizedBox(width: 6),
                              Text(
                                'Check-out:',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              '${dateFormat.format(_checkOut)} (${HotelSettingsService.checkOutTime} hs)',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.navyLuxury),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14, color: Color(0xFFF1F5F9)),

                      // Duración
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.nights_stay_outlined, size: 16, color: AppTheme.goldLuxury),
                              SizedBox(width: 6),
                              Text(
                                'Duración:',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              '$_totalNights ${_totalNights == 1 ? "noche" : "noches"}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.navyLuxury),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14, color: Color(0xFFF1F5F9)),

                      // Monto Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Monto Estimado:',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${currencyFormat.format(_totalPrice)} Gs.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Nota de prevención para el usuario
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Asegúrate de que no estás reservando con las fechas preestablecidas si tenías programado otro día.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // BOTÓN 1: SÍ, FECHAS CORRECTAS (CONFIRMAR)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyLuxury,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _proceedWithBookingCreation();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: AppTheme.goldLuxury),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Sí, Fechas Correctas',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // BOTÓN 2: MODIFICAR FECHAS
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Modificar Fechas',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanionsSection() {
    final completedCount = _companions.where((c) => c.isComplete).length;
    final allComplete = _companions.isNotEmpty && completedCount == _companions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.group_outlined, size: 20, color: AppTheme.goldLuxury),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Registro de Acompañantes',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyLuxury,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (_totalGuests > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: allComplete ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allComplete ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      allComplete ? Icons.check_circle : Icons.pending_outlined,
                      size: 13,
                      color: allComplete ? const Color(0xFF166534) : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$completedCount de ${_companions.length} listos',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: allComplete ? const Color(0xFF166534) : const Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_totalGuests <= 1)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF16A34A)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Estadía individual para 1 huésped (Titular). No se requiere el registro de acompañantes adicionales.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // Banner informativo de regulación legal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Registro de Huéspedes: Para mayor seguridad y confort, completa los datos de todos los acompañantes.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lista de tarjetas de acompañantes
          ...List.generate(_companions.length, (index) {
            final companion = _companions[index];
            final isDone = companion.isComplete;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDone ? Colors.white : const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDone ? const Color(0xFFCBD5E1) : const Color(0xFFFED7AA),
                  width: isDone ? 1 : 1.5,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isDone ? AppTheme.navyLuxury : const Color(0xFFFFF7ED),
                        child: Icon(
                          companion.isAdult ? Icons.person_outline : Icons.child_care,
                          size: 18,
                          color: isDone ? AppTheme.goldLuxury : const Color(0xFFEA580C),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isDone ? companion.fullName : 'Acompañante ${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDone ? AppTheme.navyLuxury : const Color(0xFF9A3412),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDone ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDone ? Icons.verified : Icons.warning_amber_rounded,
                                        size: 12,
                                        color: isDone ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isDone ? 'Verificado' : 'Obligatorio',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDone ? const Color(0xFF166534) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${companion.isAdult ? "Adulto" : "Menor de 12 años"} • Vínculo: ${companion.relationship}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (isDone) ...[
                    const Divider(height: 14, color: Color(0xFFF1F5F9)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGuestInfoPill(
                            Icons.badge_outlined,
                            'Documento',
                            '${companion.documentType}: ${companion.documentNumber}',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildGuestInfoPill(
                            Icons.public_outlined,
                            'Nacionalidad',
                            companion.nationality,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: () => _openEditCompanionModal(index),
                        icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryBlue),
                        label: const Text(
                          'Editar datos',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC2410C),
                          backgroundColor: const Color(0xFFFFF7ED),
                          side: const BorderSide(color: Color(0xFFFDBA74)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _openEditCompanionModal(index),
                        icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                        label: const Text(
                          'Completar datos obligatorios',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  void _openEditCompanionModal(int index) {
    if (index < 0 || index >= _companions.length) return;
    final current = _companions[index];

    final nameCtrl = TextEditingController(text: current.fullName);
    final docNumberCtrl = TextEditingController(text: current.documentNumber);
    final nationalityCtrl = TextEditingController(text: current.nationality);
    String selectedDocType = current.documentType;
    String selectedRelationship = current.relationship;

    final adultDocTypes = const ['CI', 'Pasaporte', 'DNI', 'RUC'];
    final childDocTypes = const ['CI', 'Partida de Nacimiento', 'Pasaporte', 'DNI'];
    final availableDocTypes = current.isAdult ? adultDocTypes : childDocTypes;
    if (!availableDocTypes.contains(selectedDocType)) {
      selectedDocType = availableDocTypes.first;
    }

    final adultRelations = const ['Cónyuge / Pareja', 'Familiar', 'Amigo/a', 'Colega de Trabajo', 'Otro'];
    final childRelations = const ['Hijo/a', 'Familiar a cargo', 'Sobrino/a', 'Tutelado/a'];
    final availableRelations = current.isAdult ? adultRelations : childRelations;
    if (!availableRelations.contains(selectedRelationship)) {
      selectedRelationship = availableRelations.first;
    }

    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Datos del Acompañante ${index + 1}',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navyLuxury,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${current.isAdult ? "Huésped Adulto" : "Huésped Menor (0 a 11 años)"} • Registro legal',
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Nombre y Apellido Completo
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nombre y Apellido Completo *',
                        prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tipo y Número de Documento
                    Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDocType,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Tipo *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            items: availableDocTypes.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedDocType = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: docNumberCtrl,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Nº de Documento *',
                              prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryBlue),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Parentesco / Vínculo
                    DropdownButtonFormField<String>(
                      initialValue: selectedRelationship,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Parentesco / Relación con el Titular *',
                        prefixIcon: const Icon(Icons.family_restroom_outlined, color: AppTheme.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                      items: availableRelations.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(r, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedRelationship = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Nacionalidad
                    TextFormField(
                      controller: nationalityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nacionalidad *',
                        prefixIcon: const Icon(Icons.public_outlined, color: AppTheme.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.navyLuxury,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          final doc = docNumberCtrl.text.trim();
                          final nat = nationalityCtrl.text.trim();

                          if (name.isEmpty) {
                            setModalState(() => errorMessage = 'Ingresa el nombre y apellido completo.');
                            return;
                          }
                          if (doc.isEmpty) {
                            setModalState(() => errorMessage = 'Ingresa el número de documento oficial.');
                            return;
                          }

                          setState(() {
                            _companions[index] = current.copyWith(
                              fullName: name,
                              documentType: selectedDocType,
                              documentNumber: doc,
                              nationality: nat.isNotEmpty ? nat : 'Paraguaya',
                              relationship: selectedRelationship,
                            );
                          });

                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Datos de Acompañante ${index + 1} guardados y verificados',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        child: const Text(
                          'Verificar y Guardar Acompañante',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuestInfoPill(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEditGuestModal() {
    final nameCtrl = TextEditingController(text: _guestName);
    final docNumberCtrl = TextEditingController(text: _guestDocNumber);
    final phoneCtrl = TextEditingController(text: _guestPhone);
    final nationalityCtrl = TextEditingController(text: _guestNationality);
    String selectedDocType = _guestDocType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Verificar Datos del Titular',
                            style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Text(
                      'Asegúrate de que tus datos coincidan con tu documento oficial para el registro en recepción.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 18),

                    // Nombre completo
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre y Apellido Completo',
                        prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tipo y número de documento
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDocType,
                            decoration: InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'CI', child: Text('C.I.')),
                              DropdownMenuItem(value: 'Pasaporte', child: Text('Pasap.')),
                              DropdownMenuItem(value: 'DNI', child: Text('DNI')),
                              DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedDocType = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: docNumberCtrl,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              labelText: 'Nº de Documento',
                              prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primaryBlue),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Teléfono
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Número de Teléfono',
                        prefixIcon: const Icon(Icons.phone_outlined, color: AppTheme.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nacionalidad
                    TextFormField(
                      controller: nationalityCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nacionalidad',
                        prefixIcon: const Icon(Icons.public_outlined, color: AppTheme.primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.navyLuxury,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final updatedName = nameCtrl.text.trim();
                          final updatedDoc = docNumberCtrl.text.trim();
                          final updatedPhone = phoneCtrl.text.trim();
                          final updatedNationality = nationalityCtrl.text.trim();

                          setState(() {
                            if (updatedName.isNotEmpty) _guestName = updatedName;
                            _guestDocType = selectedDocType;
                            _guestDocNumber = updatedDoc;
                            _guestPhone = updatedPhone;
                            if (updatedNationality.isNotEmpty) _guestNationality = updatedNationality;
                          });

                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Datos de huésped titular actualizados',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );

                          try {
                            await Supabase.instance.client.auth.updateUser(
                              UserAttributes(data: {
                                'full_name': _guestName,
                                'document_type': _guestDocType,
                                'document_number': _guestDocNumber,
                                'phone': _guestPhone,
                                'nationality': _guestNationality,
                              }),
                            );
                          } catch (_) {}
                        },
                        child: const Text('Confirmar Datos', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLuxurySuccessDialog(BuildContext context, String bookingCode, Booking? createdBooking) {
    // Disparo automático de confirmación oficial y folio por correo mediante Brevo API
    EmailNotificationService.sendBookingConfirmation(
      recipientEmail: widget.user.email,
      guestName: widget.user.name,
      bookingCode: bookingCode,
      roomNumber: widget.room.numero,
      roomType: widget.room.tipoNombre,
      checkIn: _checkIn,
      checkOut: _checkOut,
      totalAmount: _totalPrice,
    );

    // Disparo de notificación local en barra de estado y campanita de la App
    NotificationService().notifyUser(
      title: 'Hotel 3Vagos - Reserva Confirmada #$bookingCode',
      body: '¡Tu estadía en ${widget.room.tipoNombre} (Hab. ${widget.room.numero}) ha sido confirmada con éxito!',
      type: 'booking',
      prefKey: 'alert_pref_checkin',
      data: {
        'booking_code': bookingCode,
        'room_number': widget.room.numero,
        'room_type': widget.room.tipoNombre,
      },
    );

    final resolvedBooking = createdBooking ??
        Booking(
          id: '',
          codigoReserva: bookingCode,
          guestId: widget.user.id,
          habitacionId: widget.room.id,
          habitacionNumero: widget.room.numero,
          habitacionTipo: widget.room.tipoNombre,
          checkInPrevisto: _checkIn.toIso8601String().split('T')[0],
          checkOutPrevisto: _checkOut.toIso8601String().split('T')[0],
          cantidadHuespedes: _totalGuests,
          montoTotal: _totalPrice,
          estado: 'Confirmada',
          canalVenta: 'App Móvil',
          folioSaldoPendiente: _totalPrice,
          folioTotalPagos: 0.0,
          folioEstado: 'Abierto',
        );

    showDialog(
      context: context,
      barrierDismissible: false,
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
                Text(
                  '¡Reserva Confirmada!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyLuxury,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código: $bookingCode',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldLuxury,
                  ),
                ),
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
                        children: [
                          const Flexible(
                            child: Text(
                              'Habitación:',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.room.numero} (${widget.room.tipoNombre})',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Estadía:',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${dateFormat.format(_checkIn)} al ${dateFormat.format(_checkOut)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (_companions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Acompañantes:',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_companions.length} registrado${_companions.length > 1 ? "s" : ""} (legal)',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Total Estadía:',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${currencyFormat.format(_totalPrice)} Gs.',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyLuxury),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // PREGUNTA DE ADELANTO O PAGO
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.payment_outlined, size: 20, color: AppTheme.primaryBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¿Deseas realizar un adelanto o pago total ahora?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Puedes abonar un anticipo ahora vía app (tarjeta, SIPAP o billetera) o pagar directamente en recepción al momento del check-in.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 18),

              // BOTÓN 1: REALIZAR ADELANTO O PAGO AHORA
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyLuxury,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BookingPaymentPage(booking: resolvedBooking),
                      ),
                    );
                  },
                  icon: const Icon(Icons.payment_rounded, size: 18, color: AppTheme.goldLuxury),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Realizar Adelanto o Pago Ahora',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // BOTÓN 2: PAGAR EN EL HOTEL (IR A MIS RESERVAS)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(Icons.check_circle, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '¡Reserva garantizada! Puedes abonar tu estadía en recepción o desde la app.',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );

                    // Redirección directa y garantizada al apartado de "Mis Reservas"
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExploreRoomsPage(initialNavIndex: 1),
                      ),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.hotel_outlined, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Pagar en el Hotel (Ir a Mis Reservas)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildRatePlanSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.loyalty_rounded, color: AppTheme.navyLuxury, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Plan de Tarifa & Políticas',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyLuxury,
                ),
              ),
            ),
          ],
        ),
        if (_seasonName != null && _seasonMultiplier != 1.0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Temporada: $_seasonName (${_seasonMultiplier > 1.0 ? "+${((_seasonMultiplier - 1.0) * 100).round()}%" : "${((_seasonMultiplier - 1.0) * 100).round()}%"})',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
        // ==========================================
        // PAQUETES DE PROMOCIÓN DESTACADOS (TAREA 13)
        // ==========================================
        if (_promoPackages.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.card_giftcard_rounded, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Text(
                'PAQUETES EN PROMOCIÓN (EXPERIENCIA CERRADA)',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFB45309),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._promoPackages.map((pkg) {
            final isSelected = _selectedPromoPackage?['id'] == pkg['id'];
            final pkgPrice = (pkg['package_price'] as num?)?.toDouble() ?? 0.0;
            final pkgName = pkg['name']?.toString() ?? 'Paquete Promocional';
            final pkgDesc = pkg['description']?.toString() ?? 'Experiencia exclusiva todo incluido';
            final services = (pkg['services'] as List<dynamic>?) ?? [];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedPromoPackage = null;
                    } else {
                      _selectedPromoPackage = pkg;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Colors.white, Color(0xFFF8FAFC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFD97706) : const Color(0xFFCBD5E1),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: isSelected ? 0.15 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'MEJORA TU ESTADÍA',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pkgName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.navyLuxury,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pkgDesc,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                      ),
                      if (services.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: services.map((s) {
                            final sName = s['item_name']?.toString() ?? 'Servicio';
                            final sQty = s['quantity'] ?? 1;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                '✓ $sName (x$sQty) • 0 Gs.',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF047857), fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Precio Cerrado Paquete:',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${currencyFormat.format(pkgPrice)} Gs.',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],

        ..._ratePlans.map((plan) {
          final code = plan['code']?.toString() ?? 'flexible';
          final name = plan['name']?.toString() ?? 'Tarifa Estándar';
          final badge = plan['badge']?.toString() ?? '';
          final desc = plan['cancellation']?.toString() ?? 'Condiciones regulares de estancia';
          final discPercent = (plan['discount'] as num?)?.toDouble() ?? 0.0;
          final isSelected = _selectedRatePlan == code;

          final planPrice = _basePrice * (1.0 - (discPercent / 100.0));
          final savings = _basePrice * (discPercent / 100.0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedRatePlan = code;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (discPercent > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC))
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? (discPercent > 0 ? const Color(0xFFD97706) : AppTheme.navyLuxury)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (discPercent > 0 ? const Color(0xFFD97706) : AppTheme.navyLuxury)
                                .withValues(alpha: 0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 10),
                      child: Icon(
                        isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? (discPercent > 0 ? const Color(0xFFD97706) : AppTheme.navyLuxury)
                            : const Color(0xFF94A3B8),
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: discPercent > 0 ? const Color(0xFF92400E) : AppTheme.navyLuxury,
                                  ),
                                ),
                              ),
                              if (badge.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: discPercent > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: discPercent > 0 ? const Color(0xFFFDE68A) : const Color(0xFFBAE6FD),
                                    ),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(
                                      color: discPercent > 0 ? const Color(0xFFB45309) : const Color(0xFF0284C7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            style: TextStyle(
                              color: discPercent > 0 ? const Color(0xFF78350F) : const Color(0xFF64748B),
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (discPercent > 0)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${currencyFormat.format(planPrice)} Gs.',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${currencyFormat.format(_basePrice)} Gs.',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '-${currencyFormat.format(savings)} Gs.',
                                    style: const TextStyle(
                                      color: Color(0xFF15803D),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${currencyFormat.format(_basePrice)} Gs.',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.navyLuxury,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _dispatchPackageIncludedServices(String bookingCode, Booking? booking) async {
    if (_selectedPromoPackage == null) return;
    try {
      final client = Supabase.instance.client;
      final pkgId = _selectedPromoPackage!['id']?.toString();
      final pkgName = _selectedPromoPackage!['name']?.toString() ?? 'Paquete Promocional';

      // 1. Actualizar reserva con paquete_id y nombre_paquete
      try {
        await client.from('reservas').update({
          'paquete_id': pkgId,
          'nombre_paquete': pkgName,
          'canal_reserva': 'App Móvil',
        }).eq('codigo_reserva', bookingCode);
      } catch (_) {}

      // 2. Disparar los servicios incluidos a 0 Gs. al módulo de consumos / folio
      final services = (_selectedPromoPackage!['services'] as List<dynamic>?) ?? [];
      for (final s in services) {
        final sName = s['item_name']?.toString() ?? 'Servicio Incluido';
        final sQty = (s['quantity'] as num?)?.toInt() ?? 1;

        try {
          await client.from('consumos_habitacion').insert({
            'habitacion_id': widget.room.id,
            'item_nombre': '$sName ($pkgName)',
            'cantidad': sQty,
            'precio_unitario': 0,
            'total': 0,
            'estado': 'Pendiente de entrega',
            'observaciones': 'Incluido en paquete promocional pagado (0 Gs.)',
          });
        } catch (_) {}
      }

      // 3. Notificación local en la app
      await NotificationService().notifyUser(
        title: '¡Experiencia Promocional Activada! 🎁',
        body: 'Tu reserva $bookingCode incluye el "$pkgName" con servicios de cortesía sin cargo en tu folio.',
        type: 'promo',
      );
    } catch (e) {
      debugPrint('Error registrando servicios de paquete: $e');
    }
  }
}

