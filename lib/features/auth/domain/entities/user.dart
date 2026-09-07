import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? documentType;
  final String? documentNumber;
  final String? nationality;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.documentType,
    this.documentNumber,
    this.nationality,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? documentType,
    String? documentNumber,
    String? nationality,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      nationality: nationality ?? this.nationality,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        phone,
        documentType,
        documentNumber,
        nationality,
      ];
}
