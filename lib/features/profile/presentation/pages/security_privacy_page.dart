import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SecurityPrivacyPage extends StatefulWidget {
  const SecurityPrivacyPage({super.key});

  @override
  State<SecurityPrivacyPage> createState() => _SecurityPrivacyPageState();
}

class _SecurityPrivacyPageState extends State<SecurityPrivacyPage> {
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await BiometricService().isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
      });
    }
  }

  void _showChangePasswordModal() {
    final formKey = GlobalKey<FormState>();
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (bCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(bCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cambiar Contraseña',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyLuxury,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ingresa tu contraseña actual y define tu nueva clave de acceso.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: currentPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Contraseña Actual',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu clave actual' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Nueva Contraseña',
                      prefixIcon: const Icon(Icons.key_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Debe tener al menos 6 caracteres' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirmar Nueva Contraseña',
                      prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (v != newPassCtrl.text) return 'Las contraseñas no coinciden';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyLuxury,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isUpdating
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isUpdating = true);

                              try {
                                await Supabase.instance.client.auth.updateUser(
                                  UserAttributes(password: newPassCtrl.text.trim()),
                                );
                              } catch (_) {}

                              if (bCtx.mounted) {
                                Navigator.pop(bCtx);
                              }
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80)),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text('Contraseña actualizada con éxito'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppTheme.navyLuxury,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      child: Text(isUpdating ? 'Actualizando...' : 'Actualizar Contraseña', style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Desactivación de Cuenta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Estás seguro de que deseas desactivar tu cuenta de acceso?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Text(
                  'Por normativas de facturación y seguridad, el historial de tus reservas anteriores se mantendrá archivado.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), height: 1.35),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Se cerrará tu sesión activa y tu acceso quedará desactivado.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(dCtx); // Cierra diálogo
              Navigator.pop(context); // Sale de seguridad
              context.read<AuthBloc>().add(AuthSignOut());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cuenta desactivada. Sesión cerrada formalmente.'),
                  backgroundColor: AppTheme.navyLuxury,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Desactivar Cuenta'),
          ),
        ],
      ),
    );
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
          'Seguridad & Privacidad',
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
              'Credenciales & Autenticación',
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
                  // 1. Cambiar Contraseña
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.key_rounded, color: AppTheme.primaryBlue, size: 20),
                    ),
                    title: const Text('Cambiar Contraseña', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Actualiza tu clave periódicamente para mayor seguridad', style: TextStyle(fontSize: 11.5)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: _showChangePasswordModal,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),

                  // 2. Acceso con Huella Dactilar
                  SwitchListTile(
                    value: _biometricEnabled,
                    onChanged: (v) async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (v) {
                        final available = await BiometricService().isBiometricAvailable();
                        if (!available) {
                          if (mounted) {
                            messenger.hideCurrentSnackBar();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('El dispositivo no cuenta con sensor biométrico o huella dactilar configurada.'),
                                duration: Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Color(0xFFDC2626),
                              ),
                            );
                          }
                          return;
                        }

                        final authenticated = await BiometricService().authenticate(
                          reason: 'Confirma tu huella digital para activar el acceso biométrico en Hotel 3Vagos',
                        );

                        if (authenticated) {
                          await BiometricService().setBiometricEnabled(true);
                          if (mounted) {
                            setState(() => _biometricEnabled = true);
                            messenger.hideCurrentSnackBar();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('✓ Acceso con huella dactilar activado exitosamente.'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Color(0xFF16A34A),
                              ),
                            );
                          }
                        }
                      } else {
                        await BiometricService().setBiometricEnabled(false);
                        if (mounted) {
                          setState(() => _biometricEnabled = false);
                          messenger.hideCurrentSnackBar();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Acceso con huella dactilar desactivado.'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.navyLuxury,
                            ),
                          );
                        }
                      }
                    },
                    activeThumbColor: AppTheme.navyLuxury,
                    activeTrackColor: AppTheme.goldLuxury.withValues(alpha: 0.4),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF16A34A), size: 20),
                    ),
                    title: const Text('Acceso con Huella Dactilar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: const Text('Iniciar sesión rápidamente con la biometría del dispositivo', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Gestión de Cuenta & Datos',
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
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_remove_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                title: const Text('Eliminar / Desactivar Cuenta', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFFDC2626))),
                subtitle: const Text('Cierra y desactiva tu cuenta de forma segura', style: TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                onTap: _showDeleteAccountDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
