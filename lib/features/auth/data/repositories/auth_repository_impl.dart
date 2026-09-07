import 'package:fpdart/fpdart.dart';
import 'package:trekos_m_hotel/core/error/failures.dart';
import 'package:trekos_m_hotel/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:trekos_m_hotel/features/auth/domain/entities/user.dart';
import 'package:trekos_m_hotel/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

// Implementation of AuthRepository for Supabase
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  const AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, User>> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return _getUser(
      () => remoteDataSource.loginWithEmailPassword(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<Either<Failure, User>> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? documentType,
    String? documentNumber,
    String? nationality,
  }) async {
    return _getUser(
      () => remoteDataSource.signUpWithEmailPassword(
        name: name,
        email: email,
        password: password,
        phone: phone,
        documentType: documentType,
        documentNumber: documentNumber,
        nationality: nationality,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await remoteDataSource.signOut();
      return right(null);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> currentUser() async {
    try {
      final session = remoteDataSource.currentUserSession;
      if (session == null) {
        return left(const ServerFailure('No hay sesión activa'));
      }
      final meta = session.user.userMetadata ?? {};
      return right(User(
        id: session.user.id,
        email: session.user.email ?? '',
        name: meta['full_name'] ?? '',
        phone: meta['phone'] ?? session.user.phone,
        documentType: meta['document_type'] ?? 'CI',
        documentNumber: meta['document_number'] ?? '',
        nationality: meta['nationality'] ?? 'Paraguaya',
      ));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, User>> _getUser(Future<String> Function() fn) async {
    try {
      await fn();
      final userResponse = await currentUser();
      return userResponse;
    } on supabase.AuthException catch (e) {
      return left(ServerFailure(e.message));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
