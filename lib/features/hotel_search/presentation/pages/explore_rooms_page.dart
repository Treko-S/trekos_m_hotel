import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:trekos_m_hotel/core/services/booking_pdf_service.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trekos_m_hotel/features/auth/presentation/pages/login_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_state.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/booking_payment_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/room_detail_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/widgets/advanced_filters_modal.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/personal_data_page.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/payment_methods_page.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/stay_history_page.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/stay_reminders_page.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/security_privacy_page.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/legal_policies_page.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/my_invoices_page.dart';
import 'package:trekos_m_hotel/features/room_service/presentation/pages/services_tab.dart';
import 'package:trekos_m_hotel/core/widgets/whatsapp_speed_dial.dart';
import 'package:trekos_m_hotel/core/widgets/promo_speed_dial.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/notifications_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trekos_m_hotel/init_dependencies.dart';

class ExploreRoomsPage extends StatefulWidget {
  final int initialNavIndex;
  const ExploreRoomsPage({super.key, this.initialNavIndex = 0});

  @override
  State<ExploreRoomsPage> createState() => _ExploreRoomsPageState();
}

class _ExploreRoomsPageState extends State<ExploreRoomsPage> with WidgetsBindingObserver {
  int _currentNavIndex = 0;
  Timer? _searchDebounceTimer;
  Timer? _realtimeDebounceTimer;
  Timer? _heartbeatSyncTimer;
  RealtimeChannel? _realtimeChannel;
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialNavIndex;
    WidgetsBinding.instance.addObserver(this);
    context.read<HotelBloc>().add(const HotelFetchRooms());

    // Carga proactiva si ya existe sesión iniciada al arrancar
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      context.read<HotelBloc>().add(HotelFetchGuestBookings(authState.user.id));
    }

    _setupRealtimeSubscription();

    // Sincronización continua de respaldo cada 4 segundos (garantía de autorecarga en vivo 100% resiliente)
    _heartbeatSyncTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        _syncAllData(silent: true);
      }
    });

    // Verificación única de popup de promoción activa
    _checkAndShowPromoPopup();
  }

  Future<void> _checkAndShowPromoPopup() async {
    try {
      const storage = FlutterSecureStorage();
      final hasSeen = await storage.read(key: 'seen_promo_verano_2026');
      if (hasSeen == null && mounted) {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;
        showHotelPromoDialog(
          context,
          onDismiss: () async {
            await storage.write(key: 'seen_promo_verano_2026', value: 'true');
          },
        );
      }
    } catch (e) {
      debugPrint('Error verificando popup de promo: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sincronización instantánea al regresar a la aplicación
      _syncAllData(silent: true);
    }
  }

  void _setupRealtimeSubscription() {
    try {
      final supabase = serviceLocator<SupabaseClient>();
      _realtimeChannel = supabase
          .channel('hotel_universal_sync')
          .onBroadcast(
            event: 'hotel_data_updated',
            callback: (payload) {
              debugPrint('⚡ [Broadcast Instantáneo] Notificación de cambio recibida: $payload');
              _syncAllData(silent: true);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'habitaciones',
            callback: (payload) => _onRealtimeDataChanged('habitaciones'),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'reservas',
            callback: (payload) => _onRealtimeDataChanged('reservas'),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'folios',
            callback: (payload) => _onRealtimeDataChanged('folios'),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tipos_habitacion',
            callback: (payload) => _onRealtimeDataChanged('tipos_habitacion'),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'acompanantes',
            callback: (payload) => _onRealtimeDataChanged('acompanantes'),
          )
          .subscribe((status, [error]) {
            debugPrint('📡 [Realtime Flutter] Canal hotel_universal_sync status: $status, error: $error');
          });
      debugPrint('✅ [Realtime] Suscripción activa en vivo a broadcast y postgres changes');
    } catch (e) {
      debugPrint('❌ [Realtime] Error configurando suscripción Realtime: $e');
    }
  }

  void _onRealtimeDataChanged(String sourceTable) {
    debugPrint('🔔 [Realtime] Cambio detectado en tabla "$sourceTable" -> Agendando autorecarga con debounce...');
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _syncAllData(silent: true);
      }
    });
  }

  void _syncAllData({bool silent = false}) {
    if (!mounted) return;
    // 1. Recargar catálogo de habitaciones y disponibilidades en vivo
    context.read<HotelBloc>().add(HotelFetchRooms(isSilent: silent));

    // 2. Si el huésped está autenticado, recargar sus reservas y folios
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      context.read<HotelBloc>().add(HotelFetchGuestBookings(authState.user.id, isSilent: silent));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatSyncTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _realtimeDebounceTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<HotelBloc>().add(HotelSearchQueryChanged(query));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, authState) {
          if (authState is AuthSuccess) {
            context.read<HotelBloc>().add(HotelFetchGuestBookings(authState.user.id));
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              IndexedStack(
                index: _currentNavIndex,
                children: [
                  _buildExploreTab(context),
                  _buildBookingsTab(context),
                  const ServicesTab(),
                  _buildProfileTab(context),
                ],
              ),
              const PromoSpeedDial(),
              const WhatsAppSpeedDial(),
            ],
          ),
        ),
      ),

      // Barra de Navegación Inferior Rediseñada (Inicio, Mis Reservas, Servicios, Perfil)
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() => _currentNavIndex = index);
            if (index == 1 || index == 2) {
              final authState = context.read<AuthBloc>().state;
              if (authState is AuthSuccess) {
                context.read<HotelBloc>().add(HotelFetchGuestBookings(authState.user.id));
              }
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w500),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Mis Reservas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.room_service_outlined),
              activeIcon: Icon(Icons.room_service_rounded),
              label: 'Servicios',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: EXPLORACIÓN DE HABITACIONES (INICIO)
  // ==========================================
  Widget _buildExploreTab(BuildContext context) {
    final hotelState = context.watch<HotelBloc>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. TOP BAR CORPORATIVA (Logo Hotel 3Vagos + Notificaciones)
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: const [
                        Icon(Icons.apartment_rounded, color: AppTheme.primaryBlue, size: 24),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Icon(Icons.waves_rounded, color: AppTheme.accentCyan, size: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Hotel',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: '3Vagos',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentCyan,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Campana de notificaciones con badge interactivo
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.primaryBlue, size: 22),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsPage()),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. HERO GREETING (¡Bienvenido!)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Bienvenido!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Encuentra y reserva la habitación perfecta para tu estadía.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // 3. BUSCADOR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppTheme.primaryDark),
              decoration: InputDecoration(
                hintText: 'Buscar por número de habitación o tipo',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 22),
                suffixIcon: IconButton(
                  icon: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: hotelState.advancedFilters.isActive ? AppTheme.accentCyan : const Color(0xFF64748B),
                        size: 20,
                      ),
                      if (hotelState.advancedFilters.isActive)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Filtros Avanzados',
                  onPressed: () => AdvancedFiltersModal.show(context),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
        ),

        // Badge indicador de filtros avanzados activos
        if (hotelState.advancedFilters.isActive)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 12, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      const Text(
                        'Filtros personalizados activos',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => context.read<HotelBloc>().add(HotelResetFilters()),
                        child: const Icon(Icons.close, size: 14, color: AppTheme.primaryBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // 4. CHIPS DE FILTRO RÁPIDO
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildModernFilterChip('Todas', icon: Icons.check_circle_outline_rounded, isSelected: hotelState.selectedFilter == 'Todas'),
                _buildModernFilterChip('Simple', icon: Icons.single_bed_outlined, isSelected: hotelState.selectedFilter == 'Simple'),
                _buildModernFilterChip('Doble', icon: Icons.hotel_outlined, isSelected: hotelState.selectedFilter == 'Doble'),
                _buildModernFilterChip('Suite', icon: Icons.diamond_outlined, isSelected: hotelState.selectedFilter == 'Suite'),
                _buildModernFilterChip('Precio Más Bajo', icon: Icons.trending_down_rounded, isSelected: hotelState.selectedFilter == 'Precio Más Bajo'),
                _buildModernFilterChip('Más Alto', icon: Icons.trending_up_rounded, isSelected: hotelState.selectedFilter == 'Más Alto'),
              ],
            ),
          ),
        ),

        // 5. LISTADO DE HABITACIONES CON SKELETON SHIMMER
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              context.read<HotelBloc>().add(HotelFetchRooms());
              await Future.delayed(const Duration(milliseconds: 600));
            },
            color: AppTheme.primaryBlue,
            child: _buildRoomListContent(hotelState),
          ),
        ),
      ],
    );
  }

  Widget _buildModernFilterChip(String label, {required IconData icon, required bool isSelected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          context.read<HotelBloc>().add(HotelFilterCategoryChanged(label));
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF60A5FA).withValues(alpha: 0.9) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomListContent(HotelState state) {
    // Animación fluida de carga Shimmer
    if (state.status == HotelStatus.loading && state.rooms.isEmpty) {
      return _buildShimmerLoading();
    }

    if (state.status == HotelStatus.error && state.rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'No pudimos conectar con el servidor',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryDark),
              ),
              const SizedBox(height: 6),
              Text(
                state.errorMessage ?? 'Verifica tu conexión a internet o intenta nuevamente.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () => context.read<HotelBloc>().add(HotelFetchRooms()),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredRooms = state.filteredRooms;

    if (filteredRooms.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hotel_outlined, size: 54, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'No se encontraron habitaciones con el criterio',
                    style: GoogleFonts.poppins(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filteredRooms.length,
      itemBuilder: (context, index) {
        final room = filteredRooms[index];
        return _buildRoomCard(context, room);
      },
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFFE2E8F0),
          highlightColor: const Color(0xFFF8FAFC),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 115,
                      height: 98,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(width: 90, height: 16, color: Colors.white),
                              Container(width: 60, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(width: 120, height: 12, color: Colors.white),
                          const SizedBox(height: 12),
                          Container(width: double.infinity, height: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 90, height: 22, color: Colors.white),
                    Container(width: 85, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomCard(BuildContext context, Room room) {
    final publicState = room.estadoPublico;
    final isAvailableNow = room.isAvailableNow;
    final isOccupiedOrBooked = publicState == 'Ocupada' || (!isAvailableNow && room.canBeBooked);

    Color badgeBg;
    Color badgeColor;
    String badgeText;

    if (isAvailableNow) {
      badgeBg = AppTheme.greenBg;
      badgeColor = AppTheme.greenText;
      badgeText = 'Disponible';
    } else if (isOccupiedOrBooked) {
      badgeBg = AppTheme.blueBg;
      badgeColor = AppTheme.blueText;
      badgeText = publicState == 'Ocupada' ? 'Ocupada' : 'Reservada';
    } else {
      badgeBg = AppTheme.redBg;
      badgeColor = AppTheme.redText;
      badgeText = 'No disponible';
    }

    final coverImage = (room.imagenes.isNotEmpty ? room.imagenes.first : room.imagenCover) ??
        'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800';

    final int bedCount = room.capacidad <= 1 ? 1 : (room.capacidad <= 2 ? 1 : 2);
    final String bedText = bedCount == 1 ? '1 cama' : '$bedCount camas';
    final int sqMeters = 20 + room.capacidad * 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openRoomDetail(context, room),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. FILA SUPERIOR: IMAGEN + DETALLES
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto con bordes redondeados
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 115,
                        height: 98,
                        color: const Color(0xFFF1F5F9),
                        child: CachedNetworkImage(
                          imageUrl: coverImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade200,
                            highlightColor: Colors.grey.shade50,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Center(
                              child: Icon(Icons.hotel_rounded, size: 36, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Información textual derecha
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título y Estado con ESPACIADO ÓPTIMO garantizado
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Habitación ${room.numero}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryDark,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: badgeColor.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle, size: 6, color: badgeColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      badgeText,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          // Subtítulo tipo de habitación
                          Text(
                            room.tipoNombre,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 10),

                          // Fila de Características (Responsive & Centrado o Elipsis)
                          Row(
                            children: [
                              _buildFeaturePill(Icons.bed_outlined, bedText),
                              const SizedBox(width: 6),
                              _buildFeaturePill(Icons.person_outline, 'Hasta ${room.capacidad} pers.'),
                              const SizedBox(width: 6),
                              _buildFeaturePill(Icons.aspect_ratio_rounded, '$sqMeters m²'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),

                // 2. FILA INFERIOR: PRECIO + BOTÓN ACCIÓN (Cero Desbordamiento Garantizado)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Columna de Precio Flexible con FittedBox
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Desde',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${currencyFormat.format(room.precioBase)} Gs.',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Botón de Acción Flexible con FittedBox
                    Flexible(
                      flex: 5,
                      child: SizedBox(
                        height: 38,
                        child: isAvailableNow
                            ? FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _openRoomDetail(context, room),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Reservar',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.chevron_right_rounded, size: 18),
                                    ],
                                  ),
                                ),
                              )
                            : isOccupiedOrBooked
                                ? InkWell(
                                    onTap: () => _openRoomDetail(context, room),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.event_available_outlined,
                                              size: 14,
                                              color: Color(0xFF2563EB),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              room.textoDisponibilidad,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      foregroundColor: const Color(0xFF94A3B8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () => _openRoomDetail(context, room),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'No Disponible',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
        ),
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primaryBlue),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: MIS RESERVAS / FOLIO (CUENTA)
  // ==========================================
  Widget _buildBookingsTab(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthSuccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 64, color: AppTheme.primaryBlue),
              const SizedBox(height: 16),
              Text(
                'Consulta tus Reservas',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inicia sesión para consultar tus reservas y saldos pendientes.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginPage())),
                child: const Text('Iniciar Sesión'),
              ),
            ],
          ),
        ),
      );
    }

    final hotelState = context.watch<HotelBloc>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis Reservas',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryBlue),
                onPressed: () {
                  context.read<HotelBloc>().add(HotelFetchGuestBookings(authState.user.id));
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: (hotelState.isBookingsLoading && hotelState.guestBookings.isEmpty)
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
              : hotelState.guestBookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No tienes reservas registradas actualmente'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() => _currentNavIndex = 0),
                            child: const Text('Explorar Habitaciones'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: hotelState.guestBookings.length,
                      itemBuilder: (context, index) {
                        final booking = hotelState.guestBookings[index];
                        return BookingCardItem(
                          booking: booking,
                          currencyFormat: currencyFormat,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: PERFIL DE USUARIO (REDISEÑADO)
  // ==========================================
  Widget _buildProfileTab(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState is! AuthSuccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('assets/images/default_user.png'),
              ),
              const SizedBox(height: 16),
              Text(
                'Mi Perfil',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inicia sesión para gestionar tus datos personales, preferencias y estancias.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LoginPage())),
                  child: const Text('Iniciar Sesión'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final user = authState.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Tarjeta de Usuario Principal
          Center(
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.goldLuxury, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage('assets/images/default_user.png'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(user.email, style: const TextStyle(color: Colors.black54, fontSize: 12.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Huésped Registrado (UTCD)',
                    style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // CLUB DE FIDELIZACIÓN 3V (HUÉSPED VIP)
          // ==========================================
          _buildLoyaltyCard(context, user),
          const SizedBox(height: 24),

          // SECCIÓN 1: CUENTA
          _buildProfileCategoryHeader('Cuenta'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryBlue),
                  title: const Text('Datos Personales', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDataPage()));
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.credit_card_rounded, color: AppTheme.primaryBlue),
                  title: const Text('Métodos de Pago', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsPage()));
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.history_rounded, color: AppTheme.primaryBlue),
                  title: const Text('Historial de Estadías', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StayHistoryPage()));
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue),
                  title: const Text('Mis Facturas y Recibos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Comprobantes oficiales SET Paraguay', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyInvoicesPage()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN 2: PREFERENCIA
          _buildProfileCategoryHeader('Preferencia'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706)),
                  title: const Text('Recordatorios y Alertas de Estadía', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StayRemindersPage()));
                  },
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  leading: const Icon(Icons.security_rounded, color: AppTheme.navyLuxury),
                  title: const Text('Seguridad y Privacidad', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityPrivacyPage()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN 3: LEGAL
          _buildProfileCategoryHeader('Legal'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: const Icon(Icons.policy_outlined, color: AppTheme.navyLuxury),
              title: const Text('Políticas de Hospedaje & Cancelación', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalPoliciesPage()));
              },
            ),
          ),
          const SizedBox(height: 24),

          // Botón Cerrar Sesión
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    content: const Text('¿Deseas cerrar tu sesión actual en este dispositivo?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                        onPressed: () {
                          Navigator.pop(dCtx);
                          context.read<AuthBloc>().add(AuthSignOut());
                        },
                        child: const Text('Cerrar Sesión'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(BuildContext context, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Logo Club + Badge Nivel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CLUB DE FIDELIZACIÓN 3V',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFDE68A),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Text(
                  'SOCIO ORO VIP',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Datos del socio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Membresía #3V-884102',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '1.450',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFDE68A),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(
                    'Puntos Acumulados',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de progreso hacia Socio Platino
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.725, // 1450 / 2000
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Nivel Oro', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                  Text('Faltan 550 pts para Platino 💎', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Beneficios destacados activos
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildLoyaltyPerkBadge(Icons.access_time_rounded, 'Early / Late Check-in'),
              _buildLoyaltyPerkBadge(Icons.restaurant_rounded, '10% OFF Frigobar & Restó'),
              _buildLoyaltyPerkBadge(Icons.local_bar_rounded, 'Welcome Drink'),
            ],
          ),
          const SizedBox(height: 12),

          // Botón ver recompensas y canjes
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFDE68A),
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () => _showLoyaltyBenefitsDialog(context),
              icon: const Icon(Icons.card_giftcard_rounded, size: 16),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Ver Catálogo de Beneficios y Canjes 3V',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyPerkBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFFDE68A)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showLoyaltyBenefitsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Club Hotel 3V Luxury',
                            style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                          ),
                          const Text(
                            'Programa Oficial de Fidelización',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Catálogo de Canjes Disponibles:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyLuxury),
                ),
                const SizedBox(height: 10),
                _buildRewardItem(Icons.spa_rounded, 'Sesión de Masaje Relajante (Spa)', '1.200 pts', true),
                _buildRewardItem(Icons.restaurant_menu_rounded, 'Cena Gourmet para 2 Personas', '1.800 pts', false),
                _buildRewardItem(Icons.king_bed_rounded, 'Noche de Estadía Estándar Gratis', '3.000 pts', false),
                _buildRewardItem(Icons.more_time_rounded, 'Late Check-out garantizado hasta 16hs', '400 pts', true),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Los puntos se acreditan automáticamente tras completar el check-out de cada estadía.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyLuxury,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(dCtx),
                    child: const Text('Entendido'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardItem(IconData icon, String title, String points, bool canAfford) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: canAfford ? const Color(0xFFF8FAFC) : const Color(0xFFF8FAFC).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: canAfford ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: canAfford ? const Color(0xFFD97706) : const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: canAfford ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: canAfford ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              points,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: canAfford ? const Color(0xFFB45309) : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openRoomDetail(BuildContext context, Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDetailPage(room: room),
      ),
    );
  }
}

/// Tarjeta de reserva para clientes con detalles colapsables bajo demanda.
/// Permite mantener la vista compacta sin saturar la pantalla cuando el usuario
/// tiene múltiples reservas (ej. las 2 últimas habitaciones disponibles).
class BookingCardItem extends StatefulWidget {
  final Booking booking;
  final NumberFormat currencyFormat;

  const BookingCardItem({
    super.key,
    required this.booking,
    required this.currencyFormat,
  });

  @override
  State<BookingCardItem> createState() => _BookingCardItemState();
}

class _BookingCardItemState extends State<BookingCardItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final currencyFormat = widget.currencyFormat;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera interactiva con Código y Estado (Táctil para expandir/colapsar)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bookmark_added_rounded, size: 20, color: AppTheme.primaryBlue),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                booking.codigoReserva,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.primaryDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: booking.estado.toLowerCase() == 'confirmada'
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: booking.estado.toLowerCase() == 'confirmada'
                                ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                                : const Color(0xFF2563EB).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          booking.estado,
                          style: TextStyle(
                            color: booking.estado.toLowerCase() == 'confirmada' ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Habitación ${booking.habitacionNumero} • ${booking.habitacionTipo}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primaryDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${booking.checkInPrevisto} al ${booking.checkOutPrevisto} (${booking.noches} noche${booking.noches > 1 ? 's' : ''})',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // BARRA RESUMIDA COMPACTA: Saldo/Total + Botón "Ver detalles" / "Ocultar detalles"
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.folioSaldoPendiente > 0 ? 'Saldo pendiente:' : 'Total estadía:',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            booking.folioSaldoPendiente > 0
                                ? '${currencyFormat.format(booking.folioSaldoPendiente)} Gs.'
                                : '${currencyFormat.format(booking.granTotalGastos)} Gs. (Al día)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: booking.folioSaldoPendiente > 0 ? AppTheme.primaryBlue : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isExpanded ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isExpanded ? AppTheme.primaryBlue.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isExpanded ? 'Ocultar detalles' : 'Ver detalles',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // DETALLES COMPLETOS (DESPLEGABLE BAJO DEMANDA)
            if (_isExpanded) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Detalle de Gastos',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Estado: ${booking.folioEstado}',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16, color: Color(0xFFE2E8F0)),

                            // 1. ALOJAMIENTO
                            _buildExpenseSection(
                              icon: Icons.hotel_outlined,
                              title: 'Alojamiento',
                              subtitle: '${booking.noches} noche(s) × ${currencyFormat.format(booking.tarifaPorNoche)} Gs.',
                              amount: '${currencyFormat.format(booking.montoTotal)} Gs.',
                            ),
                            const SizedBox(height: 8),

                            // 2. CONSUMOS
                            _buildExpenseSection(
                              icon: Icons.restaurant_outlined,
                              title: 'Consumos',
                              subtitle: 'Minibar, restaurante, bebidas y otros',
                              amount: '${currencyFormat.format(booking.totalConsumos)} Gs.',
                            ),
                            const SizedBox(height: 8),

                            // 3. SERVICIOS
                            _buildExpenseSection(
                              icon: Icons.room_service_outlined,
                              title: 'Servicios',
                              subtitle: 'Lavandería, estacionamiento, spa, traslados',
                              amount: '${currencyFormat.format(booking.totalServicios)} Gs.',
                            ),
                            const SizedBox(height: 8),

                            // 4. CARGOS
                            _buildExpenseSection(
                              icon: Icons.receipt_long_outlined,
                              title: 'Cargos e Impuestos',
                              subtitle: 'IVA 10% (${currencyFormat.format(booking.iva10)} Gs.), tasas y adic.',
                              amount: '${currencyFormat.format(booking.totalCargos)} Gs.',
                            ),

                            const Divider(height: 18, color: Color(0xFFCBD5E1)),

                            // 5. PAGOS Y SALDO FINAL
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text(
                                    'Total Gastos Generales:',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${currencyFormat.format(booking.granTotalGastos)} Gs.',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                    ),
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
                                    'Pagos / Anticipos Recibidos:',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '- ${currencyFormat.format(booking.folioTotalPagos)} Gs.',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Saldo Pendiente de Pago:',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${currencyFormat.format(booking.folioSaldoPendiente)} Gs.',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            // Botones de acción del Folio: Abono y Comprobante Digital
                            Row(
                              children: [
                                if (booking.folioSaldoPendiente > 0 && booking.folioId != null) ...[
                                  Expanded(
                                    child: SizedBox(
                                      height: 42,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppTheme.navyLuxury,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => BookingPaymentPage(booking: booking),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.payment_rounded, size: 16, color: AppTheme.goldLuxury),
                                        label: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Abonar / Pagar Saldo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.navyLuxury,
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                      ),
                                      onPressed: () => _openVoucherDirectly(context, booking),
                                      icon: const Icon(Icons.receipt_long_outlined, size: 16, color: AppTheme.primaryBlue),
                                      label: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('Ver Comprobante', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _openVoucherDirectly(BuildContext context, Booking booking) async {
    final authState = context.read<AuthBloc>().state;
    String recipientEmail = 'rc652107@gmail.com';
    String guestName = 'Huésped Registrado';
    if (authState is AuthSuccess) {
      recipientEmail = authState.user.email;
      guestName = authState.user.name;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Generando comprobante y abriendo lector...',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.navyLuxury,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final result = await BookingPdfService.saveAndOpenPdf(
        booking: booking,
        guestName: guestName,
        guestEmail: recipientEmail,
      );

      final filePath = (result['cachePath'] as String?) ?? (result['path'] as String?);
      final fileName = result['fileName'] as String? ?? 'Comprobante_${booking.codigoReserva}.pdf';

      if (context.mounted && filePath != null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4ADE80), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Guardado en Descargas: $fileName',
                    style: const TextStyle(fontSize: 12.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Reabrir',
              textColor: const Color(0xFFFBBF24),
              onPressed: () => BookingPdfService.openPdf(filePath),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showDigitalVoucherDialog(context, booking);
      }
    }
  }

  void _showDigitalVoucherDialog(BuildContext context, Booking booking) {
    final authState = context.read<AuthBloc>().state;
    String recipientEmail = 'rc652107@gmail.com';
    String guestName = 'Huésped Registrado';
    if (authState is AuthSuccess) {
      recipientEmail = authState.user.email;
      guestName = authState.user.name;
    }

    final currencyFormat = widget.currencyFormat;
    final total = booking.montoTotal;
    final paid = booking.folioTotalPagos;
    final remaining = booking.folioSaldoPendiente;
    final iva10 = (total / 11).round();
    final gravada10 = (total / 1.10).round();

    bool isDownloading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Membrete Legal SET
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'HOTEL 3 VAGOS S.A.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyLuxury),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'OFICIAL',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('RUC: 80092341-2 • Timbrado N°: 16789423', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const Text('Validez: 01/01/2026 al 31/12/2026 • Asunción', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Comprobante de Reserva',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reserva: ${booking.codigoReserva} | Habitación ${booking.habitacionNumero}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),

                  // Tabla de Datos
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildVoucherDialogRow('Huésped Titular:', guestName),
                        const Divider(height: 12, color: Color(0xFFE2E8F0)),
                        _buildVoucherDialogRow('Estadía:', '${booking.checkInPrevisto} al ${booking.checkOutPrevisto}'),
                        const SizedBox(height: 4),
                        _buildVoucherDialogRow('Duración:', '${booking.noches} noche(s)'),
                        const Divider(height: 12, color: Color(0xFFE2E8F0)),
                        _buildVoucherDialogRow('Total Estadía:', '${currencyFormat.format(total)} Gs.', isBold: true),
                        const SizedBox(height: 4),
                        _buildVoucherDialogRow(
                          'Seña / Abonos:',
                          paid > 0 ? '- ${currencyFormat.format(paid)} Gs.' : '0 Gs. (Sin abono)',
                          color: const Color(0xFF16A34A),
                          isBold: true,
                        ),
                        const SizedBox(height: 4),
                        _buildVoucherDialogRow(
                          'Saldo Pendiente:',
                          remaining <= 0 ? '0 Gs. (Saldado)' : '${currencyFormat.format(remaining)} Gs.',
                          color: remaining <= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Desglose Tributario SET
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'IVA 10% (Incluido en el total):',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                        ),
                        const SizedBox(height: 4),
                        Text('• Gravadas 10%: ${currencyFormat.format(gravada10)} Gs.', style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
                        Text('• Liquidación IVA 10%: ${currencyFormat.format(iva10)} Gs.', style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
                        Text('• Exentas: 0 Gs.', style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Botón Único de Acción: Descarga Directa de PDF a la Carpeta Descargas
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyLuxury,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: isDownloading
                          ? null
                          : () async {
                              setModalState(() => isDownloading = true);

                              try {
                                final result = await BookingPdfService.saveAndOpenPdf(
                                  booking: booking,
                                  guestName: guestName,
                                  guestEmail: recipientEmail,
                                );

                                final filePath = (result['cachePath'] as String?) ?? (result['path'] as String?);
                                final fileName = result['fileName'] as String? ?? 'Comprobante_${booking.codigoReserva}.pdf';

                                // Cerrar diálogo actual para no bloquear la pantalla
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                }

                                // Notificar mediante banner flotante elegante sin tapar la pantalla del dispositivo
                                if (context.mounted && filePath != null) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4ADE80), size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Guardado en Descargas: $fileName',
                                              style: const TextStyle(fontSize: 12.5),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF0F172A),
                                      duration: const Duration(seconds: 4),
                                      behavior: SnackBarBehavior.floating,
                                      action: SnackBarAction(
                                        label: 'Reabrir',
                                        textColor: const Color(0xFFFBBF24),
                                        onPressed: () => BookingPdfService.openPdf(filePath),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isDownloading = false);
                                if (dialogCtx.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error al generar PDF: $e'),
                                      backgroundColor: const Color(0xFFDC2626),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.picture_as_pdf_rounded, size: 20, color: Color(0xFFFBBF24)),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isDownloading ? 'Guardando en Descargas...' : 'Descargar Comprobante (PDF Oficial)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Cerrar', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoucherDialogRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppTheme.navyLuxury,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
            ),
          ),
        ),
      ],
    );
  }
}

