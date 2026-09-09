import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trekos_m_hotel/features/auth/presentation/pages/login_page.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/core/services/notification_service.dart';
import 'package:trekos_m_hotel/features/profile/presentation/pages/my_invoices_page.dart';

class HotelNotificationItem {
  final String id;
  final String title;
  final String description;
  final String time;
  final String type; // 'invoice' | 'promo' | 'stay' | 'loyalty'
  bool isRead;
  final Map<String, dynamic>? data;

  HotelNotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.type,
    this.isRead = false,
    this.data,
  });
}

class NotificationsPage extends StatefulWidget {
  final Function(Map<String, dynamic> promo)? onOpenPromo;

  const NotificationsPage({super.key, this.onOpenPromo});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selectedFilter = 'todas';
  List<HotelNotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserNotifications();
  }

  /// Carga las notificaciones 100% dinámicas e independientes por usuario.
  /// Si el usuario NO ha iniciado sesión (invitado):
  /// - NO se muestran facturas de otros usuarios ni recordatorios de check-in ficticios.
  /// - Solo se muestra la promoción general activa del hotel.
  /// Si el usuario ha iniciado sesión:
  /// - Se consultan sus reservas reales de HotelBloc y sus facturas reales de Supabase.
  Future<void> _loadUserNotifications() async {
    final authState = context.read<AuthBloc>().state;
    final bool isAuthenticated = authState is AuthSuccess;
    final user = isAuthenticated ? authState.user : null;

    const storage = FlutterSecureStorage();
    final storageKey = 'notif_read_ids_${user?.id ?? "guest"}';
    Set<String> readIds = {};
    try {
      final readRaw = await storage.read(key: storageKey);
      if (readRaw != null && readRaw.isNotEmpty) {
        readIds = Set<String>.from(jsonDecode(readRaw));
      }
    } catch (_) {}

    final List<HotelNotificationItem> items = [];

    // 1. Promoción Pública de Temporada (Válida para todo público)
    items.add(
      HotelNotificationItem(
        id: 'notif_promo_verano_2026',
        title: 'Hotel 3Vagos - ¡20% OFF de Temporada!',
        description: 'Aprovecha un 20% de descuento en cualquiera de nuestras suites exclusivas utilizando el cupón VERANO2026.',
        time: 'Temporada Verano 2026',
        type: 'promo',
        isRead: readIds.contains('notif_promo_verano_2026'),
        data: {
          'code': 'VERANO2026',
          'discount': '20%',
          'title': 'Temporada Verano 2026',
          'image': 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
        },
      ),
    );

    // 2. Notificaciones Personales (SOLO si el usuario está autenticado con sesión iniciada)
    if (isAuthenticated && user != null) {
      // A. Membresía y Club de Fidelidad
      final loyaltyId = 'notif_loyalty_${user.id}';
      items.add(
        HotelNotificationItem(
          id: loyaltyId,
          title: 'Hotel 3Vagos - Club 3V Huésped',
          description: '¡Hola ${user.name}! Gracias por ser parte de nuestra comunidad hotelera. Tus reservas confirmadas acumulan puntos para beneficios.',
          time: 'Membresía Activa',
          type: 'loyalty',
          isRead: readIds.contains(loyaltyId),
        ),
      );

      // B. Estadías, Check-in y Cancelaciones de Reservas REALES del usuario
      try {
        if (!mounted) return;
        final hotelState = context.read<HotelBloc>().state;
        final bookings = hotelState.guestBookings;
        final currencyFmt = NumberFormat('#,###', 'es_PY');
        for (var b in bookings.take(6)) {
          if (b.isCancelled || b.estado.toLowerCase() == 'cancelada') {
            final cancelId = 'notif_cancel_${b.id}';
            final hasRefund = b.anticipoPagado > 0;
            final refundGs = '${currencyFmt.format(b.anticipoPagado.round()).replaceAll(',', '.')} Gs.';
            items.add(
              HotelNotificationItem(
                id: cancelId,
                title: 'Hotel 3Vagos - Cancelación de Reserva ${b.codigoReserva}',
                description: hasRefund
                    ? 'Tu reserva para la Hab. ${b.habitacionNumero} (${b.habitacionTipo}) ha sido cancelada. ✓ Reembolso aprobado por $refundGs correspondiente a tu seña adelantada (acreditación en proceso).'
                    : 'Tu reserva para la Hab. ${b.habitacionNumero} (${b.habitacionTipo}) ha sido cancelada exitosamente.',
                time: 'Cancelación Registrada',
                type: 'stay',
                isRead: readIds.contains(cancelId),
                data: {
                  'booking_id': b.id,
                  'booking_code': b.codigoReserva,
                  'refund_amount': b.anticipoPagado,
                  'is_cancelled': true,
                },
              ),
            );
          } else {
            final stayId = 'notif_stay_${b.id}';
            items.add(
              HotelNotificationItem(
                id: stayId,
                title: 'Hotel 3Vagos - Reserva ${b.codigoReserva}',
                description: 'Tu estadía en ${b.habitacionTipo} (Hab. ${b.habitacionNumero}) está agendada del ${b.checkInPrevisto} al ${b.checkOutPrevisto}. Check-in disponible a las 14:00 hs.',
                time: 'Hab. ${b.habitacionNumero}',
                type: 'stay',
                isRead: readIds.contains(stayId),
                data: {'booking_id': b.id},
              ),
            );
          }
        }
      } catch (_) {}

      // C. Facturas Oficiales REALES vinculadas al usuario
      try {
        if (!mounted) return;
        final client = Supabase.instance.client;
        final hotelState = context.read<HotelBloc>().state;
        final userFolioIds = hotelState.guestBookings
            .map((b) => b.folioId)
            .where((f) => f != null && f.isNotEmpty)
            .toSet();

        final facturasRes = await client
            .from('facturas')
            .select('*')
            .order('fecha_emision', ascending: false)
            .limit(10);

        final currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

        for (var item in (facturasRes as List<dynamic>? ?? [])) {
          final fId = item['folio_id']?.toString() ?? '';
          final doc = item['ruc_ci']?.toString().trim() ?? '';
          final name = item['razon_social']?.toString().toLowerCase() ?? '';

          final matchesFolio = fId.isNotEmpty && userFolioIds.contains(fId);
          final matchesDoc = user.documentNumber != null &&
              user.documentNumber!.trim().isNotEmpty &&
              (doc == user.documentNumber || doc.contains(user.documentNumber!));
          final matchesName = user.name.trim().isNotEmpty &&
              name.contains(user.name.trim().toLowerCase());

          if (matchesFolio || matchesDoc || matchesName) {
            final invNum = item['numero_factura']?.toString() ?? 'Oficial';
            final total = (item['monto_total'] as num?)?.toDouble() ?? 0.0;
            final invId = 'notif_inv_${item['id'] ?? invNum}';

            items.add(
              HotelNotificationItem(
                id: invId,
                title: 'Hotel 3Vagos - Factura Legal SET $invNum',
                description: 'Tu factura oficial por ${currencyFormat.format(total)} Gs. correspondiente a tu reserva está disponible para descargar en PDF.',
                time: 'Factura Oficial',
                type: 'invoice',
                isRead: readIds.contains(invId),
                data: {'invoice_number': invNum},
              ),
            );
          }
        }
      } catch (_) {}
    }

    // 3. Notificaciones Locales / Broadcast Almacenadas en NotificationService
    try {
      final storedList = await NotificationService().getStoredNotifications();
      final now = DateTime.now();
      for (var s in storedList) {
        // Evitar duplicados si ya existe un item con el mismo ID
        if (items.any((it) => it.id == s.id)) continue;

        String timeStr;
        if (now.difference(s.createdAt).inDays == 0 && now.day == s.createdAt.day) {
          timeStr = 'Hoy ${DateFormat('HH:mm').format(s.createdAt)}';
        } else if (now.difference(s.createdAt).inDays <= 1) {
          timeStr = 'Ayer ${DateFormat('HH:mm').format(s.createdAt)}';
        } else {
          timeStr = DateFormat('dd/MM HH:mm').format(s.createdAt);
        }

        items.insert(
          0,
          HotelNotificationItem(
            id: s.id,
            title: s.title,
            description: s.body,
            time: timeStr,
            type: s.type == 'cancel' || s.type == 'booking' || s.type == 'folio' ? 'stay' : s.type,
            isRead: s.isRead || readIds.contains(s.id),
            data: s.data,
          ),
        );
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthSuccess ? authState.user.id : null;
    const storage = FlutterSecureStorage();
    final storageKey = 'notif_read_ids_${userId ?? "guest"}';

    final allIds = _notifications.map((n) => n.id).toList();
    await storage.write(key: storageKey, value: jsonEncode(allIds));
    await NotificationService().markAllAsRead();

    if (mounted) {
      setState(() {
        for (var n in _notifications) {
          n.isRead = true;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas las notificaciones marcadas como leídas'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleNotificationTap(HotelNotificationItem item) async {
    if (!item.isRead) {
      setState(() {
        item.isRead = true;
      });
      final authState = context.read<AuthBloc>().state;
      final userId = authState is AuthSuccess ? authState.user.id : null;
      const storage = FlutterSecureStorage();
      final storageKey = 'notif_read_ids_${userId ?? "guest"}';

      final readRaw = await storage.read(key: storageKey);
      final Set<String> readIds = readRaw != null && readRaw.isNotEmpty
          ? Set<String>.from(jsonDecode(readRaw))
          : {};
      readIds.add(item.id);
      await storage.write(key: storageKey, value: jsonEncode(readIds.toList()));
      await NotificationService().markAsRead(item.id);
    }

    if (!mounted) return;

    if (item.type == 'invoice') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyInvoicesPage()),
      );
    } else if (item.type == 'promo') {
      if (item.data != null) {
        _showPromoDialog(item.data!);
      }
    }
  }

  void _showPromoDialog(Map<String, dynamic> promo) {
    showDialog(
      context: context,
      builder: (dCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Image.network(
                    promo['image'] ?? 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      height: 180,
                      color: AppTheme.navyLuxury,
                      child: const Center(child: Icon(Icons.hotel_rounded, size: 48, color: AppTheme.goldLuxury)),
                    ),
                  ),
                  Container(
                    height: 180,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(dCtx),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'DESCUENTO DEL ${promo['discount'] ?? "20%"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      promo['title'] ?? 'Promoción de Temporada',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyLuxury,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Disfruta de una experiencia inolvidable con tarifas preferenciales en todas nuestras habitaciones y suites.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CÓDIGO DE CUPÓN', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                              Text(
                                promo['code'] ?? 'VERANO2026',
                                style: GoogleFonts.sourceCodePro(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navyLuxury,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.navyLuxury,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.pop(dCtx);
                              Navigator.pop(context); // Volver al catálogo de habitaciones
                            },
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.goldLuxury),
                            label: const Text('Reservar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
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
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final bool isAuthenticated = authState is AuthSuccess;

    final filtered = _notifications.where((n) {
      if (_selectedFilter == 'facturas') return n.type == 'invoice';
      if (_selectedFilter == 'promos') return n.type == 'promo';
      if (_selectedFilter == 'estadia') return n.type == 'stay' || n.type == 'loyalty';
      return true;
    }).toList();

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notificaciones & Alertas',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navyLuxury,
        elevation: 0.5,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Leído todo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner para usuarios no autenticados
          if (!isAuthenticated)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.primaryBlue),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Modo Invitado: Inicia sesión para recibir alertas de tus reservas, check-in y facturas oficiales.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                    },
                    child: const Text('Ingresar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // Barra de Filtros
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('todas', 'Todas ($unreadCount no leídas)'),
                  const SizedBox(width: 8),
                  _buildFilterChip('facturas', 'Facturas & Pagos'),
                  const SizedBox(width: 8),
                  _buildFilterChip('promos', 'Promociones'),
                  const SizedBox(width: 8),
                  _buildFilterChip('estadia', 'Estadía'),
                ],
              ),
            ),
          ),

          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryBlue),
                        ),
                        SizedBox(height: 12),
                        Text('Sincronizando notificaciones...', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                : filtered.isEmpty
                    ? _buildEmptyState(isAuthenticated)
                    : RefreshIndicator(
                        onRefresh: _loadUserNotifications,
                        color: AppTheme.primaryBlue,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final notif = filtered[idx];
                            return _buildNotificationCard(notif);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isAuthenticated) {
    IconData emptyIcon = Icons.notifications_off_outlined;
    String emptyTitle = 'No hay notificaciones en este apartado';
    String emptySubtitle = 'Aquí verás las alertas y novedades relacionadas con tu cuenta y estadías.';
    Widget? actionButton;

    if (!isAuthenticated) {
      if (_selectedFilter == 'facturas') {
        emptyIcon = Icons.receipt_long_outlined;
        emptyTitle = 'Sin facturas activas';
        emptySubtitle = 'Inicia sesión con tu cuenta para visualizar los comprobantes legales SET de tus reservas.';
        actionButton = _buildLoginActionButton();
      } else if (_selectedFilter == 'estadia') {
        emptyIcon = Icons.hotel_outlined;
        emptyTitle = 'Sin estadías registradas';
        emptySubtitle = 'Inicia sesión para recibir alertas del estado de tu habitación, check-in y folio.';
        actionButton = _buildLoginActionButton();
      }
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 40, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.navyLuxury),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 18),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoginActionButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.navyLuxury,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
      },
      icon: const Icon(Icons.login_rounded, size: 16, color: AppTheme.goldLuxury),
      label: const Text('Iniciar Sesión', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: AppTheme.navyLuxury,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF475569),
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildNotificationCard(HotelNotificationItem notif) {
    IconData icon;
    Color iconColor;
    Color iconBg;

    final isCancelled = notif.data != null && notif.data!['is_cancelled'] == true;

    if (isCancelled) {
      icon = Icons.cancel_outlined;
      iconColor = const Color(0xFFDC2626);
      iconBg = const Color(0xFFFEE2E2);
    } else {
      switch (notif.type) {
        case 'invoice':
          icon = Icons.receipt_long_rounded;
          iconColor = const Color(0xFF16A34A);
          iconBg = const Color(0xFFDCFCE7);
          break;
        case 'promo':
          icon = Icons.local_offer_rounded;
          iconColor = const Color(0xFFD97706);
          iconBg = const Color(0xFFFEF3C7);
          break;
        case 'stay':
          icon = Icons.hotel_rounded;
          iconColor = AppTheme.primaryBlue;
          iconBg = const Color(0xFFEFF6FF);
          break;
        case 'loyalty':
        default:
          icon = Icons.stars_rounded;
          iconColor = const Color(0xFF7C3AED);
          iconBg = const Color(0xFFEDE9FE);
          break;
      }
    }

    return InkWell(
      onTap: () => _handleNotificationTap(notif),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notif.isRead ? const Color(0xFFE2E8F0) : AppTheme.primaryBlue.withValues(alpha: 0.3),
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: GoogleFonts.poppins(
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 13.5,
                            color: AppTheme.navyLuxury,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notif.time,
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                      if (notif.type == 'invoice')
                        Row(
                          children: const [
                            Text(
                              'Ver Factura',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, size: 14, color: Color(0xFF16A34A)),
                          ],
                        )
                      else if (notif.type == 'promo')
                        Row(
                          children: const [
                            Text(
                              'Ver Oferta',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, size: 14, color: Color(0xFFD97706)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
