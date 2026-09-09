import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../services/biometric_service.dart';

class BiometricSessionGuard extends StatefulWidget {
  final Widget child;

  const BiometricSessionGuard({
    super.key,
    required this.child,
  });

  @override
  State<BiometricSessionGuard> createState() => _BiometricSessionGuardState();
}

class _BiometricSessionGuardState extends State<BiometricSessionGuard>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _pausedTimestamp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedTimestamp = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    if (_isAuthenticating || _isLocked) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthSuccess) return;

    final bool isBiometricEnabled = await BiometricService().isBiometricEnabled();
    if (!isBiometricEnabled) return;

    // Si la app estuvo en segundo plano más de 20 segundos
    final pausedAt = _pausedTimestamp;
    final bool shouldLock = pausedAt == null ||
        DateTime.now().difference(pausedAt) > const Duration(seconds: 20);

    if (shouldLock) {
      setState(() {
        _isLocked = true;
      });
      _requestBiometricUnlock();
    }
  }

  Future<void> _requestBiometricUnlock() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final success = await BiometricService().authenticate(
        reason: 'Verificación de seguridad: Escanea tu huella para acceder a Hotel 3Vagos',
      );

      if (mounted) {
        if (success) {
          setState(() {
            _isLocked = false;
            _pausedTimestamp = null;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Positioned.fill(
            child: Material(
              color: AppTheme.navyLuxury,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo o Escudo de Seguridad
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                          ),
                          child: const Icon(
                            Icons.fingerprint_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Hotel 3Vagos',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          'Acceso Seguro Protegido',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.goldLuxury,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'Por tu seguridad bancaria y confidencialidad de tus reservas y facturas, confirma tu identidad biométrica para continuar.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: const Color(0xFF94A3B8),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Botón de autenticación
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isAuthenticating ? null : _requestBiometricUnlock,
                            icon: _isAuthenticating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.fingerprint_rounded, size: 22),
                            label: Text(
                              _isAuthenticating ? 'Comprobando Huella...' : 'Escanear Huella Dactilar',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Opción de salida segura
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isLocked = false;
                            });
                            context.read<AuthBloc>().add(AuthSignOut());
                          },
                          child: Text(
                            'Cerrar Sesión Segura',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFEF4444),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
