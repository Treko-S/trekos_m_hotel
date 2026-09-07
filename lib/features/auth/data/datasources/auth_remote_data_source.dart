import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRemoteDataSource {
  Session? get currentUserSession;
  Future<String> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? documentType,
    String? documentNumber,
    String? nationality,
  });
  Future<String> loginWithEmailPassword({
    required String email,
    required String password,
  });
  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;
  AuthRemoteDataSourceImpl(this.supabaseClient);

  @override
  Session? get currentUserSession => supabaseClient.auth.currentSession;

  @override
  Future<String> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? documentType,
    String? documentNumber,
    String? nationality,
  }) async {
    try {
      final response = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'phone': phone,
          'document_type': documentType ?? 'CI',
          'document_number': documentNumber,
          'nationality': nationality ?? 'Paraguaya',
        },
      );
      if (response.user == null) throw Exception('Error al crear usuario');
      return response.user!.id;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<String> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) throw Exception('Usuario o contraseña incorrectos');
      return response.user!.id;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  @override
  Future<void> signOut() async {
    await supabaseClient.auth.signOut();
  }
}
