import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/hotel_settings_service.dart';

class LegalPoliciesPage extends StatefulWidget {
  const LegalPoliciesPage({super.key});

  @override
  State<LegalPoliciesPage> createState() => _LegalPoliciesPageState();
}

class _LegalPoliciesPageState extends State<LegalPoliciesPage> {
  @override
  void initState() {
    super.initState();
    HotelSettingsService.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Políticas del Hotel',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera amigable
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.hotel_rounded, color: AppTheme.navyLuxury, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenido a ${HotelSettingsService.hotelName}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: AppTheme.navyLuxury,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Guía rápida para disfrutar de una estadía placentera y segura.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Horarios
            _buildConciseCard(
              title: 'Horarios de Estadía',
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF1D4ED8),
              bgColor: const Color(0xFFEFF6FF),
              items: [
                'Check-in: Desde las ${HotelSettingsService.checkInTime} hs',
                'Check-out: Hasta las ${HotelSettingsService.checkOutTime} hs',
                'Late Check-out: Sujeto a disponibilidad en recepción',
              ],
            ),
            const SizedBox(height: 12),

            // 2. Cancelaciones y Seña
            _buildConciseCard(
              title: 'Cancelación y Políticas',
              icon: Icons.event_busy_rounded,
              iconColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFEF3C7),
              items: [
                HotelSettingsService.cancellationPolicyText,
                'Reembolsos para pagos móviles se reintegran directamente a tu cuenta bancaria.',
              ],
            ),
            const SizedBox(height: 12),

            // 3. Servicios y Consumos
            _buildConciseCard(
              title: 'Servicios a la Habitación',
              icon: Icons.room_service_rounded,
              iconColor: AppTheme.navyLuxury,
              bgColor: const Color(0xFFF1F5F9),
              items: [
                'Disponibles tras registrar tu Check-in en recepción',
                'Se cargan a tu habitación y se abonan cómodamente al Check-out',
              ],
            ),
            const SizedBox(height: 12),

            // 4. Convivencia
            _buildConciseCard(
              title: 'Convivencia y Cuidado',
              icon: Icons.smoke_free_rounded,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF3E8FF),
              items: [
                'Habitaciones 100% libres de humo',
                'Horario de silencio y descanso a partir de las 22:00 hs',
              ],
            ),
            const SizedBox(height: 12),

            // 5. Facturación
            _buildConciseCard(
              title: 'Facturación y Pagos',
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF16A34A),
              bgColor: const Color(0xFFDCFCE7),
              items: [
                'Todos los precios incluyen IVA (10%)',
                'Comprobante legal oficial disponible en recepción y en la app',
              ],
            ),
            const SizedBox(height: 20),

            // Pie discreto
            Center(
              child: Text(
                'Hotel 3 Vagos S.A. • RUC 80092341-2',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildConciseCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyLuxury,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0, left: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      it,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
