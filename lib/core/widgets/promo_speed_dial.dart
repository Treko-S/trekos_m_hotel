import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';

class PromoSpeedDial extends StatelessWidget {
  final VoidCallback? onTap;

  const PromoSpeedDial({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 74, // Ubicado directamente por encima del icono flotante de WhatsApp
      child: Tooltip(
        message: 'Promoción Activa: 20% OFF',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap ?? () => showHotelPromoDialog(context),
            customBorder: const CircleBorder(),
            splashColor: Colors.white30,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showHotelPromoDialog(
  BuildContext context, {
  Map<String, dynamic>? promo,
  VoidCallback? onDismiss,
}) {
  final p = promo ?? {
    'code': 'VERANO2026',
    'discount': '20%',
    'title': 'Temporada Verano 2026',
    'desc': 'Disfruta de tarifas especiales con un 20% de descuento en suites y habitaciones de lujo con desayuno y acceso a piscina incluidos.',
    'image': 'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
  };

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dCtx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen de portada con banner de descuento
            Stack(
              alignment: Alignment.topRight,
              children: [
                Image.network(
                  p['image'],
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 190,
                    color: const Color(0xFF0F172A),
                    child: const Center(
                      child: Icon(Icons.hotel_rounded, color: Color(0xFFFDE68A), size: 50),
                    ),
                  ),
                ),
                Container(
                  height: 190,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent, Colors.black38],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () {
                    Navigator.pop(dCtx);
                    if (onDismiss != null) onDismiss();
                  },
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '¡${p['discount']} DE DESCUENTO!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: Color(0xFFD97706), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PROMOCIÓN OFICIAL HOTEL 3VAGOS',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFB45309),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p['title'],
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyLuxury,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p['desc'],
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: 18),

                  // Caja con código de cupón y botón de copiar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Código de Cupón Activo:',
                                style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['code'],
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB45309),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: p['code']));
                            Navigator.pop(dCtx);
                            if (onDismiss != null) onDismiss();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('¡Cupón ${p['code']} copiado al portapapeles!'),
                                backgroundColor: const Color(0xFF166534),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copiar'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón Cerrar
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.navyLuxury,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(dCtx);
                        if (onDismiss != null) onDismiss();
                      },
                      child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
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
