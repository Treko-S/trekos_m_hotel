import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trekos_m_hotel/features/auth/presentation/pages/login_page.dart';
import 'package:trekos_m_hotel/features/auth/presentation/pages/signup_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/create_booking_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/widgets/photo_gallery_viewer.dart';

class RoomDetailPage extends StatefulWidget {
  final Room room;

  const RoomDetailPage({super.key, required this.room});

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Refresco proactivo inmediato de la habitación al entrar
    context.read<HotelBloc>().add(const HotelFetchRooms(isSilent: true));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hotelState = context.watch<HotelBloc>().state;
    final room = hotelState.rooms.where((r) => r.id == widget.room.id).firstOrNull ?? widget.room;
    final publicState = room.estadoPublico;
    final images = room.imagenes.isNotEmpty
        ? room.imagenes
        : [room.imagenCover ?? 'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800'];

    // Si se eliminó una foto o cambió la cantidad, ajustar el índice dinámicamente
    if (_currentImageIndex >= images.length) {
      _currentImageIndex = (images.length - 1).clamp(0, 9999);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentImageIndex);
        }
      });
    }

    Color badgeColor;
    IconData badgeIcon;
    String badgeTitle;
    if (publicState == 'No disponible') {
      badgeColor = AppTheme.redText;
      badgeIcon = Icons.do_not_disturb_on_outlined;
      badgeTitle = 'NO DISPONIBLE';
    } else if (room.hasImminentBooking) {
      badgeColor = const Color(0xFF2563EB);
      badgeIcon = Icons.event_busy_rounded;
      badgeTitle = 'RESERVADA';
    } else if (publicState == 'Ocupada') {
      badgeColor = const Color(0xFF3B82F6);
      badgeIcon = Icons.king_bed_outlined;
      badgeTitle = 'OCUPADA';
    } else {
      badgeColor = const Color(0xFF10B981);
      badgeIcon = Icons.circle;
      badgeTitle = 'DISPONIBLE';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          context.read<HotelBloc>().add(const HotelFetchRooms(isSilent: false));
          await Future.delayed(const Duration(milliseconds: 500));
        },
        color: AppTheme.goldLuxury,
        backgroundColor: AppTheme.navyLuxury,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          // ==========================================
          // 1. APPBAR CON GALERÍA DE FOTOS INTERACTIVA
          // ==========================================
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppTheme.navyLuxury,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enlace de habitación copiado al portapapeles')),
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // PageView para deslizar entre varias fotos (con click para Zoom)
                  GestureDetector(
                    onTap: () => PhotoGalleryViewer.show(
                      context,
                      images: images,
                      initialIndex: _currentImageIndex,
                      title: 'Habitación ${room.numero}',
                    ),
                    child: PageView.builder(
                      key: ValueKey('gallery_${room.id}_${images.length}_${images.join()}'),
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFF1E293B),
                            child: const Center(
                              child: Icon(Icons.hotel, size: 64, color: AppTheme.goldLuxury),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Gradiente inferior para mejorar legibilidad
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Badge de Estado y Contador de Fotos con indicador de Zoom
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, color: Colors.white, size: badgeIcon == Icons.circle ? 8 : 13),
                              const SizedBox(width: 6),
                              Text(
                                badgeTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Indicador de foto actual
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentImageIndex + 1} / ${images.length} fotos',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==========================================
          // 2. CUERPO DETALLADO DE LA HABITACIÓN
          // ==========================================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mini selector de miniaturas de fotos
                  if (images.length > 1)
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        key: ValueKey('thumbs_${room.id}_${images.length}_${images.join()}'),
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final isSelected = index == _currentImageIndex;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 60,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppTheme.goldLuxury : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(images[index], fit: BoxFit.cover),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Título y Categoría
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Habitación ${room.numero}',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navyLuxury,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${room.tipoNombre} • Piso ${room.piso}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppTheme.goldLuxury,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.people_alt_outlined, color: AppTheme.navyLuxury, size: 20),
                            Text(
                              '${room.capacidad} Pers.',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Estado de Disponibilidad y Fechas Libres
                  _buildAvailabilityCard(room),

                  const SizedBox(height: 20),

                  // Descripción Completa
                  Text(
                    'Descripción del Alojamiento',
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    room.tipoDescripcion.isNotEmpty
                        ? room.tipoDescripcion
                        : 'Ambiente exclusivo diseñado para brindar el máximo confort y elegancia. Cuenta con mobiliario de alta gama, iluminación ambiental cálida y servicio de atención personalizada 24 horas.',
                    style: const TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.6),
                  ),

                  const SizedBox(height: 24),

                  // Matriz de Características Remarcadas
                  Text(
                    'Aspectos y Comodidades Incluidas',
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                  ),
                  const SizedBox(height: 14),

                  _buildFeatureGrid(room),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Políticas de Estadía
                  Text(
                    'Información de Estadía & Horarios',
                    style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                  ),
                  const SizedBox(height: 12),

                  _buildPolicyCard(
                    icon: Icons.login_rounded,
                    title: 'Check-in',
                    subtitle: 'A partir de las 14:00 hs (Recepción 24 hs disponible)',
                  ),
                  const SizedBox(height: 8),
                  _buildPolicyCard(
                    icon: Icons.logout_rounded,
                    title: 'Check-out',
                    subtitle: 'Hasta las 11:00 hs (Late check-out sujeto a disponibilidad)',
                  ),
                  const SizedBox(height: 8),
                  _buildPolicyCard(
                    icon: Icons.shield_outlined,
                    title: 'Cancelación Flexible',
                    subtitle: 'Cancelación gratuita hasta 24 horas antes del ingreso.',
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      ),

      // ==========================================
      // 3. BARRA INFERIOR DE ACCIÓN (ZERO OVERFLOW)
      // ==========================================
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Precio por noche (Responsive)
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${currencyFormat.format(room.precioBase)} Gs.',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navyLuxury,
                        ),
                      ),
                    ),
                    const Text(
                      'Impuestos incluidos',
                      style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Botón de Reserva (Responsive y Seguro)
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: room.canBeBooked ? AppTheme.navyLuxury : const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: room.canBeBooked ? () => _handleReservationFlow(context, room) : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            room.isAvailableNow && room.bookedRanges.isEmpty
                                ? Icons.calendar_today_rounded
                                : (room.canBeBooked ? Icons.event_available_outlined : Icons.do_not_disturb_on_outlined),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            room.isAvailableNow && room.bookedRanges.isEmpty
                                ? 'Reservar Ahora'
                                : (room.canBeBooked ? 'Reservar Fechas Libres' : 'No disponible'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityCard(Room room) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final hasBookings = room.bookedRanges.isNotEmpty;
    final hasImminent = room.hasImminentBooking;
    final isTrulyFree = room.isAvailableForGuest && !hasBookings;
    final isImminentlyBooked = room.isAvailableForGuest && hasImminent;
    final isFreeNowWithFutureBookings = room.isAvailableForGuest && hasBookings && !hasImminent;
    final isOccupied = room.estadoPublico == 'Ocupada';

    Color bgColor;
    Color borderColor;
    Color iconColor;
    Color titleColor;
    Color textColor;
    IconData iconData;
    String titleText;
    String descriptionText;

    if (isTrulyFree) {
      // 1. Totalmente disponible sin ninguna reserva previa
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFFBBF7D0);
      iconColor = const Color(0xFF16A34A);
      titleColor = const Color(0xFF166534);
      textColor = const Color(0xFF15803D);
      iconData = Icons.check_circle_outline_rounded;
      titleText = 'Totalmente Disponible';
      descriptionText =
          'Esta habitación está 100% libre sin reservas previas. Puedes realizar tu reserva con ingreso inmediato o para cualquier fecha de tu preferencia.';
    } else if (isImminentlyBooked) {
      // 2. Con reserva inminente (hoy o mañana)
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
      iconColor = const Color(0xFF2563EB);
      titleColor = const Color(0xFF1E40AF);
      textColor = const Color(0xFF1E3A8A);
      iconData = Icons.event_busy_rounded;
      final nextFreeStr = dateFormat.format(room.nextAvailableDate);
      titleText = 'Reservada Próximamente';
      descriptionText =
          'Esta habitación ya cuenta con una reserva confirmada para los próximos días. Se encuentra disponible para tu estadía a partir del $nextFreeStr o en fechas libres posteriores.';
    } else if (isFreeNowWithFutureBookings) {
      // 3. Libre hoy pero con reservas programadas más adelante
      bgColor = const Color(0xFFFEFCE8);
      borderColor = const Color(0xFFFEF08A);
      iconColor = const Color(0xFFCA8A04);
      titleColor = const Color(0xFF854D0E);
      textColor = const Color(0xFF713F12);
      iconData = Icons.event_available_rounded;
      titleText = 'Disponible Ahora (Fechas Futuras Reservadas)';
      descriptionText =
          'Habitación libre para ingreso inmediato hoy. Ten en cuenta que cuenta con reservas programadas para fechas posteriores (indicadas abajo). Elige tus fechas de estadía dentro de los días libres.';
    } else if (isOccupied) {
      // 4. Huésped hospedado actualmente
      bgColor = const Color(0xFFEFF6FF);
      borderColor = const Color(0xFFBFDBFE);
      iconColor = const Color(0xFF2563EB);
      titleColor = const Color(0xFF1E40AF);
      textColor = const Color(0xFF1E3A8A);
      iconData = Icons.king_bed_outlined;
      final nextFreeStr = dateFormat.format(room.nextAvailableDate);
      titleText = 'Habitación Actualmente Ocupada';
      descriptionText =
          'Actualmente con huésped hospedado. Disponible a partir del $nextFreeStr. ¡Puedes reservarla para fechas posteriores o periodos libres!';
    } else {
      // 5. Fuera de servicio
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFECACA);
      iconColor = const Color(0xFFDC2626);
      titleColor = const Color(0xFF991B1B);
      textColor = const Color(0xFFB91C1C);
      iconData = Icons.block_outlined;
      titleText = 'Habitación No Disponible';
      descriptionText =
          'Esta habitación se encuentra temporalmente fuera de servicio operativo por mantenimiento o inspección.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconData, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            descriptionText,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              height: 1.4,
            ),
          ),
          if (room.bookedRanges.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.date_range_outlined, size: 14, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Periodos reservados para esta habitación:',
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
              children: room.bookedRanges.map((range) {
                final start = dateFormat.format(range.checkIn);
                final end = dateFormat.format(range.checkOut);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
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
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(Room room) {
    final List<Map<String, dynamic>> features = [
      {'icon': Icons.wifi, 'title': 'WiFi Alta Velocidad', 'desc': 'Fibra óptica dedicada'},
      {'icon': Icons.ac_unit, 'title': 'Climatización Frío/Calor', 'desc': 'Control individual A/C'},
      {'icon': Icons.tv, 'title': 'Smart TV 55" 4K', 'desc': 'Cable & Streaming'},
      {'icon': Icons.kitchen, 'title': 'Frigobar Surtido', 'desc': 'Bebidas y snacks'},
      {'icon': Icons.shower_outlined, 'title': 'Baño en Suite', 'desc': 'Ducha efecto lluvia'},
      {'icon': Icons.free_breakfast_outlined, 'title': 'Desayuno Buffet', 'desc': 'Incluido en la tarifa'},
      {'icon': Icons.room_service_outlined, 'title': 'Room Service', 'desc': 'Atención a la habitación'},
      {'icon': Icons.lock_outline, 'title': 'Caja Fuerte Digital', 'desc': 'Seguridad personal'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feat = features[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.navyLuxury.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(feat['icon'] as IconData, color: AppTheme.navyLuxury, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      feat['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.navyLuxury),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      feat['desc'] as String,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicyCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.goldLuxury, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyLuxury)),
                Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleReservationFlow(BuildContext context, Room room) {
    final authState = context.read<AuthBloc>().state;

    if (authState is AuthSuccess) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateBookingPage(
            room: room,
            user: authState.user,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, color: AppTheme.navyLuxury, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  'Identificación de Huésped',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyLuxury,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para continuar con la reserva de esta habitación, inicia sesión con tu cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navyLuxury,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const LoginPage()),
                      );
                    },
                    child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navyLuxury,
                      side: const BorderSide(color: AppTheme.navyLuxury, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const SignUpPage()),
                      );
                    },
                    child: const Text('Registrarse', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
