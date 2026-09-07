import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class StayRemindersPage extends StatefulWidget {
  const StayRemindersPage({super.key});

  @override
  State<StayRemindersPage> createState() => _StayRemindersPageState();
}

class _StayRemindersPageState extends State<StayRemindersPage> {
  bool _checkInAlert = true;
  bool _roomReadyAlert = true;
  bool _folioChargesAlert = true;
  bool _checkOutAlert = true;
  bool _whatsAppSummaryAlert = true;
  bool _promotionsAlert = false;

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
          'Recordatorios & Alertas',
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alertas de Llegada & Estancia',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Aviso de Check-in (14:00 Hs)',
                    subtitle: 'Recordatorio 2 horas antes de tu llegada prevista al hotel.',
                    icon: Icons.login_rounded,
                    value: _checkInAlert,
                    onChanged: (v) => setState(() => _checkInAlert = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Habitación Lista',
                    subtitle: 'Aviso cuando tu habitación esté lista para ingresar.',
                    icon: Icons.cleaning_services_rounded,
                    value: _roomReadyAlert,
                    onChanged: (v) => setState(() => _roomReadyAlert = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Consumos a la Habitación',
                    subtitle: 'Avisos al cargar pedidos a la cuenta de tu habitación.',
                    icon: Icons.receipt_long_rounded,
                    value: _folioChargesAlert,
                    onChanged: (v) => setState(() => _folioChargesAlert = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            Text(
              'Alertas de Salida & Canales',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Aviso de Check-out (11:00 Hs)',
                    subtitle: 'Alerta a las 10:00 hs para entrega de llaves y liquidación en recepción.',
                    icon: Icons.logout_rounded,
                    value: _checkOutAlert,
                    onChanged: (v) => setState(() => _checkOutAlert = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Comprobantes por WhatsApp Oficial',
                    subtitle: 'Recibir foliatura digital y comprobantes al +595 993 554920.',
                    icon: Icons.chat_rounded,
                    value: _whatsAppSummaryAlert,
                    onChanged: (v) => setState(() => _whatsAppSummaryAlert = v),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Promociones & Descuentos UTCD',
                    subtitle: 'Tarifas preferenciales para estudiantes y convenios institucionales.',
                    icon: Icons.local_offer_outlined,
                    value: _promotionsAlert,
                    onChanged: (v) => setState(() => _promotionsAlert = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.navyLuxury,
      activeTrackColor: AppTheme.goldLuxury.withValues(alpha: 0.35),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.navyLuxury, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.navyLuxury),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
      ),
    );
  }
}
