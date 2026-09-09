import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final documentNumberController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  
  String _selectedDocumentType = 'CI';
  String? _selectedNationality;
  String? _fullPhoneNumber;
  
  final formKey = GlobalKey<FormState>();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  final List<String> _nationalities = [
    'Paraguaya',
    'Argentina',
    'Brasileña',
    'Uruguaya',
    'Colombiana',
    'Boliviana',
    'Chilena',
    'Española',
    'Norteamericana',
    'Otra'
  ];

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    documentNumberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _inputStyle(String label, {Widget? suffixIcon, String? hintText, EdgeInsetsGeometry? contentPadding}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: Colors.black54, fontSize: 13),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.navyLuxury, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCream,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.navyLuxury),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              ),
            );
          }
          if (state is AuthSuccess) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Crear Cuenta',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyLuxury,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ingresa tus datos para gestionar tu estadía',
                    style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  
                  // Nombre y Apellido
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: firstNameController,
                          style: const TextStyle(color: AppTheme.navyLuxury),
                          decoration: _inputStyle('Nombre'),
                          validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: lastNameController,
                          style: const TextStyle(color: AppTheme.navyLuxury),
                          decoration: _inputStyle('Apellido'),
                          validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tipo de Documento y Número Flexibles (Sin Overflow)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDocumentType,
                          isExpanded: true,
                          decoration: _inputStyle('Tipo', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: AppTheme.navyLuxury, fontSize: 13, fontWeight: FontWeight.bold),
                          items: ['CI', 'Pasaporte', 'RUC']
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDocumentType = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: documentNumberController,
                          style: const TextStyle(color: AppTheme.navyLuxury),
                          decoration: _inputStyle('Nº Documento / Pasaporte'),
                          validator: (v) => v!.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nacionalidad
                  DropdownButtonFormField<String>(
                    initialValue: _selectedNationality,
                    hint: const Text('Seleccionar Nacionalidad', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    decoration: _inputStyle('Nacionalidad'),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: AppTheme.navyLuxury, fontSize: 14),
                    items: _nationalities
                        .map((nat) => DropdownMenuItem(value: nat, child: Text(nat)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedNationality = val),
                    validator: (v) => v == null ? 'Selecciona tu nacionalidad' : null,
                  ),
                  const SizedBox(height: 16),

                  // Teléfono Internacional
                  IntlPhoneField(
                    style: const TextStyle(color: AppTheme.navyLuxury),
                    dropdownTextStyle: const TextStyle(color: AppTheme.navyLuxury),
                    decoration: _inputStyle('Número de Teléfono'),
                    initialCountryCode: 'PY',
                    onChanged: (phone) {
                      _fullPhoneNumber = phone.completeNumber;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Correo Electrónico
                  TextFormField(
                    controller: emailController,
                    style: const TextStyle(color: AppTheme.navyLuxury),
                    decoration: _inputStyle('Correo electrónico', hintText: 'usuario@gmail.com'),
                    validator: (v) {
                      if (v == null || !v.endsWith('@gmail.com')) return 'Usa un correo @gmail.com';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Contraseña
                  TextFormField(
                    controller: passwordController,
                    obscureText: _obscurePass,
                    style: const TextStyle(color: AppTheme.navyLuxury),
                    decoration: _inputStyle('Contraseña', suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: AppTheme.navyLuxury),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    )),
                    validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 16),

                  // Confirmar Contraseña
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirm,
                    style: const TextStyle(color: AppTheme.navyLuxury),
                    decoration: _inputStyle('Confirmar contraseña', suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppTheme.navyLuxury),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    )),
                    validator: (v) => v != passwordController.text ? 'Las contraseñas no coinciden' : null,
                  ),
                  const SizedBox(height: 36),

                  // Botón de Registro
                  state is AuthLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.navyLuxury))
                      : SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.navyLuxury,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                final fullName = '${firstNameController.text.trim()} ${lastNameController.text.trim()}';
                                context.read<AuthBloc>().add(
                                      AuthSignUp(
                                        email: emailController.text.trim(),
                                        password: passwordController.text,
                                        name: fullName,
                                        phone: _fullPhoneNumber ?? '',
                                        documentType: _selectedDocumentType,
                                        documentNumber: documentNumberController.text.trim(),
                                        nationality: _selectedNationality,
                                      ),
                                    );
                              }
                            },
                            child: const Text('Comenzar ahora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
