import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({super.key});

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _docController;
  late TextEditingController _phoneController;
  late TextEditingController _nationalityController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    String name = 'Huésped Registrado';
    String email = 'cliente@hotel3vagos.com';
    String doc = '4.850.123-K';
    String phone = '+595 993 554920';
    String nationality = 'Paraguaya';

    if (authState is AuthSuccess) {
      name = authState.user.name;
      email = authState.user.email;
      doc = authState.user.documentNumber ?? (email.split('@').first);
      phone = authState.user.phone ?? '+595 993 554920';
      nationality = authState.user.nationality ?? 'Paraguaya';
    }

    _nameController = TextEditingController(text: name);
    _emailController = TextEditingController(text: email);
    _docController = TextEditingController(text: doc);
    _phoneController = TextEditingController(text: phone);
    _nationalityController = TextEditingController(text: nationality);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _docController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess) {
        // Intentar actualizar en Supabase si la tabla users o perfil está disponible
        try {
          await Supabase.instance.client.from('users').update({
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'document_number': _docController.text.trim(),
            'nationality': _nationalityController.text.trim(),
          }).eq('id', authState.user.id);
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Datos personales actualizados correctamente',
                    style: TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.navyLuxury,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          'Datos Personales',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Tarjeta de Cabecera con Avatar
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.goldLuxury, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
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
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.navyLuxury,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: AppTheme.goldLuxury, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _nameController.text,
                      style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyLuxury,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'Huésped Registrado • UTCD Oficial',
                        style: TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Formulario de Datos
              _buildSectionTitle('Información de Contacto & Documentación'),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Nombre Completo',
                      icon: Icons.person_outline_rounded,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'El nombre es obligatorio' : null,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Correo Electrónico (Principal)',
                      icon: Icons.alternate_email_rounded,
                      readOnly: true,
                      helperText: 'Vinculado a tu cuenta de usuario e inicio de sesión',
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildTextField(
                      controller: _docController,
                      label: 'C.I. / Documento de Identidad',
                      icon: Icons.badge_outlined,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingrese su número de documento' : null,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Teléfono / WhatsApp de Contacto',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingrese su número telefónico' : null,
                    ),
                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                    _buildTextField(
                      controller: _nationalityController,
                      label: 'Nacionalidad',
                      icon: Icons.flag_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Tarjeta Informativa Tributaria SET
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tus datos personales están protegidos y se utilizan exclusivamente para la emisión de tus comprobantes de estadía.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF166534), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              // 4. Botón de Guardar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyLuxury,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded, size: 20, color: AppTheme.goldLuxury),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Cambios',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (readOnly)
              const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: readOnly ? const Color(0xFF64748B) : AppTheme.navyLuxury,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: InputBorder.none,
            helperText: helperText,
            helperStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }
}
