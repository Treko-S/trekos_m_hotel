import 'package:fpdart/fpdart.dart';
import 'package:trekos_m_hotel/core/error/failures.dart';
import 'package:trekos_m_hotel/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    required String phone,
    String? documentType,
    String? documentNumber,
    String? nationality,
  });

  Future<Either<Failure, User>> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> signOut();

  Future<Either<Failure, User>> currentUser();
}
