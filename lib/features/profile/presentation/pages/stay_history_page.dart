import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/booking_pdf_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../hotel_search/domain/entities/booking.dart';
import '../../../hotel_search/presentation/bloc/hotel_bloc.dart';

class StayHistoryPage extends StatelessWidget {
  const StayHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'es_PY');
    final hotelState = context.watch<HotelBloc>().state;
    final allBookings = hotelState.guestBookings;

    // Filtramos estadías pasadas o finalizadas exclusivamente (Check-out, Finalizada, Cancelada)
    final now = DateTime.now();
    final pastStays = allBookings.where((b) {
      final isFinishedState = b.estado.toLowerCase().contains('check-out') ||
          b.estado.toLowerCase().contains('checkout') ||
          b.estado.toLowerCase().contains('finalizada') ||
          b.estado.toLowerCase().contains('completada') ||
          b.estado.toLowerCase().contains('cancelada');

      final outDate = DateTime.tryParse(b.checkOutPrevisto);
      final isPastDate = outDate != null && outDate.isBefore(now) && !b.estado.toLowerCase().contains('estadia') && !b.estado.toLowerCase().contains('estadía');

      return isFinishedState || isPastDate;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.navyLuxury, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Historial de Estadías',
          style: GoogleFonts.poppins(
            color: AppTheme.navyLuxury,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: pastStays.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.hotel_outlined, size: 48, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin Estadías Previas',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyLuxury,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tus habitaciones y comprobantes de estadías anteriores aparecerán aquí una vez finalizado el Check-out.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: pastStays.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (ctx, index) {
                final booking = pastStays[index];
                return _buildStayCard(context, booking, currencyFormat);
              },
            ),
    );
  }

  Widget _buildStayCard(BuildContext context, Booking booking, NumberFormat currencyFormat) {
    final total = booking.montoTotal;
    final paid = booking.folioTotalPagos;
    final isSettled = booking.folioSaldoPendiente <= 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la Tarjeta con Código y Estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 18, color: AppTheme.navyLuxury),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Habitación ${booking.habitacionNumero}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.navyLuxury),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSettled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSettled ? 'Estadía Liquidada' : 'Saldo Pendiente',
                    style: TextStyle(
                      color: isSettled ? const Color(0xFF166534) : const Color(0xFFB45309),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoría de Habitación
                Text(
                  booking.habitacionTipo,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyLuxury,
                  ),
                ),
                const SizedBox(height: 8),

                // Período de Estadía
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${booking.checkInPrevisto} al ${booking.checkOutPrevisto} (${booking.noches} noches)',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Código de Reserva
                Row(
                  children: [
                    const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Comprobante: ${booking.codigoReserva}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFF1F5F9)),

                // Desglose Financiero
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monto Total Estadía:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text(
                      '${currencyFormat.format(total)} Gs.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Abonado:', style: TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                    Text(
                      '${currencyFormat.format(paid)} Gs.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Botón de Comprobante PDF Oficial
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openStayReceipt(context, booking),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 17, color: Color(0xFFFBBF24)),
                    label: const Text('Ver Comprobante Oficial', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStayReceipt(BuildContext context, Booking booking) async {
    final authState = context.read<AuthBloc>().state;
    String guestName = 'Huésped Registrado';
    String guestEmail = 'cliente@hotel3vagos.com';

    if (authState is AuthSuccess) {
      guestName = authState.user.name;
      guestEmail = authState.user.email;
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
              child: Text('Abriendo comprobante de estadía...', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        backgroundColor: AppTheme.navyLuxury,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await BookingPdfService.saveAndOpenPdf(
        booking: booking,
        guestName: guestName,
        guestEmail: guestEmail,
      );
    } catch (_) {}
  }
}
