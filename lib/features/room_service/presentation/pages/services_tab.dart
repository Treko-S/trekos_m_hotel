import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../hotel_search/domain/entities/booking.dart';
import '../../../hotel_search/presentation/bloc/hotel_bloc.dart';
import '../../../hotel_search/presentation/bloc/hotel_event.dart';

import '../../../hotel_search/presentation/widgets/photo_gallery_viewer.dart';

class ServiceItem {
  final String id;
  final String title;
  final String description;
  final int priceGs;
  final int? costGs;
  final String category; // "Room Service", "Minibar", "Spa & Relax", "Servicios Extra"
  final String? brand;
  final String? barcode;
  final String? promotion;
  final IconData icon;
  final String? imageUrl;
  final bool isAvailableInApp;

  const ServiceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.priceGs,
    this.costGs,
    required this.category,
    this.brand,
    this.barcode,
    this.promotion,
    required this.icon,
    this.imageUrl,
    this.isAvailableInApp = true,
  });
}

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  String _selectedCategory = 'Todos';

  static const List<ServiceItem> _defaultCatalog = [
    ServiceItem(
      id: 's1',
      title: 'Desayuno Buffet Americano Extra',
      description: 'Desayuno completo en el salón comedor con frutas, café, jugos y panificados.',
      priceGs: 65000,
      costGs: 25000,
      category: 'Servicios Extra',
      brand: 'Restaurante 3 Vagos',
      barcode: '7840001000018',
      promotion: 'Gratis para Huéspedes Socios Diamante',
      icon: Icons.breakfast_dining_rounded,
      imageUrl: 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=800',
      isAvailableInApp: true,
    ),
    ServiceItem(
      id: 's2',
      title: 'Masaje Relajante Descontracturante (50 min)',
      description: 'Sesión terapéutica en cabina de spa con aromaterapia y aceites esenciales.',
      priceGs: 180000,
      costGs: 60000,
      category: 'Spa & Relax',
      brand: 'Spa & Relax 3 Vagos',
      barcode: '7840001000025',
      promotion: '20% OFF para Socios Platino y Diamante',
      icon: Icons.spa_rounded,
      imageUrl: 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=800',
      isAvailableInApp: true,
    ),
    ServiceItem(
      id: 's3',
      title: 'Agua Mineral sin Gas 500ml',
      description: 'Agua purificada fría de manantial en botella PET.',
      priceGs: 12000,
      costGs: 4000,
      category: 'Minibar',
      brand: 'Dasani / Manantial',
      barcode: '7840001000032',
      promotion: '1 Unidad de Cortesía en Habitación Suite',
      icon: Icons.local_drink_rounded,
      imageUrl: 'https://nfbiqdhiowroosvfazid.supabase.co/storage/v1/object/public/hotel-rooms/products/agua_mineral_500ml.jpg',
      isAvailableInApp: true,
    ),
    ServiceItem(
      id: 's4',
      title: 'Cerveza Corona Extra 355ml',
      description: 'Cerveza rubia importada fría con gajo de lima.',
      priceGs: 25000,
      costGs: 12000,
      category: 'Minibar',
      brand: 'Corona Extra',
      barcode: '7840001000049',
      promotion: 'Happy Hour Minibar Viernes 2x1',
      icon: Icons.sports_bar_rounded,
      imageUrl: 'https://nfbiqdhiowroosvfazid.supabase.co/storage/v1/object/public/hotel-rooms/products/cerveza_corona_355ml.jpg',
      isAvailableInApp: true,
    ),
    ServiceItem(
      id: 's5',
      title: 'Hamburguesa Gourmet 3 Vagos con Papas',
      description: 'Carne angus 200g, queso cheddar, cebolla caramelizada y salsa especial.',
      priceGs: 55000,
      costGs: 22000,
      category: 'Room Service',
      brand: 'Cocina Gourmet 3V',
      barcode: '7840001000056',
      promotion: '10% OFF para Socios Oro y Platino',
      icon: Icons.lunch_dining_rounded,
      imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
      isAvailableInApp: true,
    ),
    ServiceItem(
      id: 's6',
      title: 'Lavandería & Planchado Express (x Prenda)',
      description: 'Lavado y planchado en el día con entrega en percha a la habitación.',
      priceGs: 30000,
      costGs: 10000,
      category: 'Servicios Extra',
      brand: 'Lavandería Central 3V',
      barcode: '7840001000063',
      promotion: 'Planchado express de 1 traje incluido en Suite',
      icon: Icons.iron_rounded,
      imageUrl: 'https://images.unsplash.com/photo-1517677208171-0bc6725a3e60?w=800',
      isAvailableInApp: false, // Pausado / Agotado en Web Admin
    ),
  ];

  late List<ServiceItem> _items = List.from(_defaultCatalog);

  @override
  void initState() {
    super.initState();
    _loadCatalogFromStorage();
    _subscribeToCatalogUpdates();
  }

  void _subscribeToCatalogUpdates() {
    try {
      final channel = Supabase.instance.client.channel('hotel_universal_sync');
      channel.onBroadcast(event: 'hotel_data_updated', callback: (payload) {
        final table = payload['table']?.toString() ?? '';
        if (table == 'catalogo_servicios' || table == 'hotel_catalog_sales') {
          _loadCatalogFromStorage();
        }
      }).subscribe();
    } catch (_) {}
  }

  Future<void> _loadCatalogFromStorage() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nfbiqdhiowroosvfazid.supabase.co/storage/v1/object/public/hotel-rooms/catalog/sales_catalog.json',
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode == 200 && response.data != null) {
        final rawData = response.data;
        final List list = rawData is List ? rawData : (rawData is String ? jsonDecode(rawData) : []);
        final List<ServiceItem> fetched = [];

        for (final item in list) {
          if (item is Map) {
            final cat = item['category']?.toString() ?? 'Servicios Extra';
            IconData icon = Icons.local_offer_rounded;
            final lowerName = item['name']?.toString().toLowerCase() ?? '';
            if (cat.contains('Minibar')) {
              icon = lowerName.contains('agua') ? Icons.local_drink_rounded : Icons.sports_bar_rounded;
            } else if (cat.contains('Spa')) {
              icon = Icons.spa_rounded;
            } else if (cat.contains('Room Service')) {
              icon = Icons.lunch_dining_rounded;
            } else if (cat.contains('Lavander') || lowerName.contains('lavad')) {
              icon = Icons.iron_rounded;
            } else {
              icon = Icons.breakfast_dining_rounded;
            }

            fetched.add(ServiceItem(
              id: item['id']?.toString() ?? 's_${DateTime.now().millisecondsSinceEpoch}',
              title: item['name']?.toString() ?? 'Producto',
              description: item['description']?.toString() ?? '',
              priceGs: (item['price'] is num) ? (item['price'] as num).toInt() : (int.tryParse(item['price']?.toString() ?? '') ?? 10000),
              costGs: (item['cost'] is num) ? (item['cost'] as num).toInt() : (int.tryParse(item['cost']?.toString() ?? '') ?? 5000),
              category: cat,
              brand: item['brand']?.toString(),
              barcode: item['barcode']?.toString(),
              promotion: item['promo']?.toString(),
              icon: icon,
              imageUrl: item['imageUrl']?.toString(),
              isAvailableInApp: item['availableInApp'] != false,
            ));
          }
        }

        if (mounted && fetched.isNotEmpty) {
          setState(() {
            _items = fetched;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'es_PY');
    final hotelState = context.watch<HotelBloc>().state;
    final guestBookings = hotelState.guestBookings;

    // Regla de Oro: Validación de Estado "Ocupada" o "Check-in"
    final activeOccupiedBooking = guestBookings.cast<Booking?>().firstWhere(
      (b) =>
          b != null &&
          (b.estado.toLowerCase() == 'ocupada' ||
              b.estado.toLowerCase() == 'check-in' ||
              b.estado.toLowerCase() == 'en curso'),
      orElse: () => null,
    );

    final isOccupied = activeOccupiedBooking != null;

    final filteredCatalog = _selectedCategory == 'Todos'
        ? _items
        : _items.where((item) => item.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.room_service_rounded, color: AppTheme.primaryBlue, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servicios & Room Service',
                    style: GoogleFonts.poppins(
                      color: AppTheme.navyLuxury,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Cargar a la Habitación (Charge to Room)',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tarjeta de Estado: Si NO está ocupada, se muestra la restricción
                  if (!isOccupied)
                    _buildNotOccupiedBanner()
                  else
                    _buildActiveOccupiedCard(activeOccupiedBooking, currencyFormat),

                  const SizedBox(height: 18),

                  // 2. Filtros de Categorías
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Todos', 'Room Service', 'Minibar', 'Spa & Relax', 'Servicios Extra'].map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                            label: Text(cat),
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.navyLuxury,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isSelected ? AppTheme.navyLuxury : const Color(0xFFE2E8F0)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Carta & Servicios Disponibles (${filteredCatalog.length})',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyLuxury,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Listado del Catálogo de Servicios
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = filteredCatalog[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildServiceItemCard(
                      context,
                      item,
                      isOccupied,
                      activeOccupiedBooking,
                      currencyFormat,
                    ),
                  );
                },
                childCount: filteredCatalog.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner Informativo cuando el huésped aún no tiene check-in físico realizado en recepción
  Widget _buildNotOccupiedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.room_service_outlined, color: Color(0xFFB45309), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Servicio a la Habitación',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Disponible al registrar tu Check-in en recepción. Puedes explorar el menú mientras tanto.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.35),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Habitación Activa cuando el huésped sí está físicamente en el hotel ("Ocupada")
  Widget _buildActiveOccupiedCard(Booking booking, NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'ESTADÍA OCUPADA (EN CURSO)',
                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                'Reserva: ${booking.codigoReserva}',
                style: const TextStyle(color: AppTheme.goldLuxury, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Habitación ${booking.habitacionNumero} (${booking.habitacionTipo})',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Los pedidos se agregarán a tu cuenta y se abonarán al realizar el Check-out.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const Divider(height: 20, color: Colors.white12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CONSUMOS DE ESTADÍA', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                  Text(
                    '${currencyFormat.format(booking.totalConsumos)} Gs.',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('SALDO TOTAL PENDIENTE', style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
                  Text(
                    '${currencyFormat.format(booking.folioSaldoPendiente)} Gs.',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta de cada servicio con foto interactiva, zoom y botón de "Cargar a la Habitación"
  Widget _buildServiceItemCard(
    BuildContext context,
    ServiceItem item,
    bool isOccupied,
    Booking? activeBooking,
    NumberFormat currencyFormat,
  ) {
    final priceLabel = item.priceGs == 0 ? 'Gratuito' : '${currencyFormat.format(item.priceGs)} Gs.';
    final isAvailable = item.isAvailableInApp;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showServiceDetailModal(context, item, isOccupied, activeBooking, currencyFormat),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Imagen / Miniatura con Visor de Fotos Interactivo al tocar (Zoom)
                  GestureDetector(
                    onTap: () {
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
                        PhotoGalleryViewer.show(
                          context,
                          images: [item.imageUrl!],
                          title: item.title,
                        );
                      }
                    },
                child: Stack(
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(item.icon, color: AppTheme.navyLuxury, size: 28),
                              ),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.navyLuxury),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(item.icon, color: AppTheme.navyLuxury, size: 28),
                            ),
                    ),
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // 2. Información del Producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila de Categoría y Disponibilidad
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            item.category,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                        if (!isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Pausado / Agotado',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.navyLuxury),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),

                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Fila de Precio y Acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PRECIO OFICIAL', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
                  Text(
                    priceLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: item.priceGs == 0 ? const Color(0xFF16A34A) : AppTheme.navyLuxury,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: (!isAvailable)
                        ? const Color(0xFFCBD5E1)
                        : (isOccupied ? AppTheme.navyLuxury : const Color(0xFF94A3B8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (!isAvailable)
                      ? null
                      : () {
                          if (!isOccupied) {
                            _showRequireCheckInModal(context);
                          } else {
                            _showOrderConfirmationSheet(context, item, activeBooking!, currencyFormat);
                          }
                        },
                  icon: Icon(
                    (!isAvailable)
                        ? Icons.block_rounded
                        : (isOccupied ? Icons.add_shopping_cart_rounded : Icons.lock_outline_rounded),
                    size: 14,
                    color: (!isAvailable)
                        ? const Color(0xFF64748B)
                        : (isOccupied ? AppTheme.goldLuxury : Colors.white),
                  ),
                  label: Text(
                    (!isAvailable)
                        ? 'No disponible'
                        : (isOccupied ? 'Cargar a la Habitación' : 'Requiere Check-in'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: (!isAvailable) ? const Color(0xFF64748B) : Colors.white,
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
);
  }

  void _showServiceDetailModal(
    BuildContext context,
    ServiceItem item,
    bool isOccupied,
    Booking? activeBooking,
    NumberFormat currencyFormat,
  ) {
    final priceLabel = item.priceGs == 0 ? 'Gratuito' : '${currencyFormat.format(item.priceGs)} Gs.';
    final isAvailable = item.isAvailableInApp;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(bCtx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Imagen Grande del Producto
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: Icon(item.icon, size: 54, color: AppTheme.navyLuxury),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Categoría y Disponibilidad
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      item.category,
                      style: const TextStyle(color: Color(0xFF1E40AF), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAvailable ? 'Disponible 24/7' : 'Pausado Temporalmente',
                      style: TextStyle(
                        color: isAvailable ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Título
              Text(
                item.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyLuxury,
                ),
              ),
              const SizedBox(height: 6),

              // Precio
              Text(
                priceLabel,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.goldLuxury,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Descripción Detallada
              Text(
                'Descripción del Producto / Servicio',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                item.description,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.5),
              ),
              const SizedBox(height: 14),

              // Ficha de Especificación Comercial (Marca, Código de Barras, Promoción)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (item.brand != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Marca Oficial:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          Text(item.brand!, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (item.barcode != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Código de Barras:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          Row(
                            children: [
                              const Icon(Icons.qr_code_rounded, size: 14, color: Color(0xFF475569)),
                              const SizedBox(width: 4),
                              Text(item.barcode!, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (item.promotion != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Beneficio / Promo:', style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.promotion!,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Información Operativa de Entrega
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.room_service_outlined, size: 18, color: AppTheme.navyLuxury),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Entrega y servicio directo a la puerta de tu habitación.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.receipt_outlined, size: 18, color: AppTheme.navyLuxury),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El importe se carga a tu folio y se liquida al realizar el Check-out.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botón de Acción
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: (!isAvailable)
                        ? const Color(0xFF94A3B8)
                        : (isOccupied ? AppTheme.navyLuxury : const Color(0xFF64748B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (!isAvailable)
                      ? null
                      : () {
                          Navigator.pop(bCtx);
                          if (!isOccupied) {
                            _showRequireCheckInModal(context);
                          } else {
                            _showOrderConfirmationSheet(context, item, activeBooking!, currencyFormat);
                          }
                        },
                  icon: Icon(
                    (!isAvailable)
                        ? Icons.block_rounded
                        : (isOccupied ? Icons.add_shopping_cart_rounded : Icons.info_outline_rounded),
                    size: 18,
                    color: isOccupied ? AppTheme.goldLuxury : Colors.white,
                  ),
                  label: Text(
                    (!isAvailable)
                        ? 'No disponible en este momento'
                        : (isOccupied ? 'Pedir y Cargar a la Habitación' : 'Disponible durante tu Estadía'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequireCheckInModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.lock_clock_rounded, color: Color(0xFFD97706), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Check-in Físico Requerido',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Para solicitar servicios de gastronomía o amenidades con el flujo "Charge to Room", es obligatorio que tu estadía figure en estado "Ocupada".\n\nAcércate a la recepción al llegar al hotel para que el recepcionista realice tu Check-in y te entregue la tarjeta de acceso.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.navyLuxury),
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showOrderConfirmationSheet(
    BuildContext context,
    ServiceItem item,
    Booking booking,
    NumberFormat currencyFormat,
  ) {
    int quantity = 1;
    final noteCtrl = TextEditingController();
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sCtx) => StatefulBuilder(
        builder: (sCtx, setSheetState) {
          final totalAmount = item.priceGs * quantity;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sCtx).viewInsets.bottom + 24,
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
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                        Container(
                          width: 52,
                          height: 52,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(item.icon, color: AppTheme.navyLuxury, size: 24),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navyLuxury,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Hab. ${booking.habitacionNumero}',
                          style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),

                  // Selector de Cantidad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cantidad a Solicitar:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.navyLuxury),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF64748B)),
                            onPressed: quantity > 1 ? () => setSheetState(() => quantity--) : null,
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.navyLuxury),
                            onPressed: quantity < 10 ? () => setSheetState(() => quantity++) : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Instrucción Adicional
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      hintText: 'Instrucciones especiales (ej. sin aderezos, entregar a las 21:00 hs)...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Desglose de Cargo a la Habitación
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total del Pedido:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text(
                              totalAmount == 0 ? '0 Gs. (Gratuito)' : '${currencyFormat.format(totalAmount)} Gs.',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF16A34A)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Se cargará a la cuenta de tu habitación y se abona al Check-out.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF166534)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botón de Confirmación
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyLuxury,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isProcessing
                          ? null
                          : () async {
                              setSheetState(() => isProcessing = true);
                              await _processChargeToRoom(
                                context,
                                sCtx,
                                item,
                                quantity,
                                totalAmount,
                                booking,
                                currencyFormat,
                              );
                            },
                      icon: isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.room_service_rounded, color: AppTheme.goldLuxury, size: 18),
                      label: Text(
                        isProcessing
                            ? 'Cargando a la habitación...'
                            : '¿Desea cargar ${totalAmount == 0 ? "este servicio" : "Gs. ${currencyFormat.format(totalAmount)}"} a su cuenta?',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  Future<void> _processChargeToRoom(
    BuildContext context,
    BuildContext sheetCtx,
    ServiceItem item,
    int quantity,
    int totalAmount,
    Booking booking,
    NumberFormat currencyFormat,
  ) async {
    try {
      final folioId = booking.folioId;
      final newConsumos = booking.totalConsumos + totalAmount;
      final newSaldo = booking.folioSaldoPendiente + totalAmount;

      if (folioId != null && folioId.isNotEmpty) {
        // Impacto directo en Supabase (tabla folios)
        await Supabase.instance.client.from('folios').update({
          'total_consumos': newConsumos,
          'saldo_pendiente': newSaldo,
        }).eq('id', folioId);
      }

      // Recargar reservas del huésped en HotelBloc para reflejar el nuevo folio
      if (context.mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthSuccess) {
          context.read<HotelBloc>().add(HotelFetchGuestBookings(authState.user.id));
        }
      }

      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx); // Cierra bottom sheet
      }

      if (context.mounted) {
        _showOrderSuccessDialog(context, item, quantity, totalAmount, booking, currencyFormat);
      }
    } catch (e) {
      if (sheetCtx.mounted) {
        Navigator.pop(sheetCtx);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar pedido: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showOrderSuccessDialog(
    BuildContext context,
    ServiceItem item,
    int quantity,
    int totalAmount,
    Booking booking,
    NumberFormat currencyFormat,
  ) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Padding(
          padding: const EdgeInsets.only(top: 12.0),
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
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Pedido en Preparación!',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Se cargó ${totalAmount == 0 ? "el servicio" : "Gs. ${currencyFormat.format(totalAmount)}"} a tu habitación ${booking.habitacionNumero}.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$quantity x ${item.title}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Te lo llevaremos a la habitación. Podrás abonarlo cómodamente al hacer Check-out.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.navyLuxury),
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
