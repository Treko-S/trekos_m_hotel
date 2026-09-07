import 'package:equatable/equatable.dart';

class CompanionGuest extends Equatable {
  final String id;
  final String fullName;
  final String documentType;
  final String documentNumber;
  final String nationality;
  final bool isAdult;
  final String relationship;

  const CompanionGuest({
    required this.id,
    this.fullName = '',
    this.documentType = 'CI',
    this.documentNumber = '',
    this.nationality = 'Paraguaya',
    this.isAdult = true,
    this.relationship = 'Acompañante',
  });

  bool get isComplete =>
      fullName.trim().isNotEmpty && documentNumber.trim().isNotEmpty;

  CompanionGuest copyWith({
    String? id,
    String? fullName,
    String? documentType,
    String? documentNumber,
    String? nationality,
    bool? isAdult,
    String? relationship,
  }) {
    return CompanionGuest(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      nationality: nationality ?? this.nationality,
      isAdult: isAdult ?? this.isAdult,
      relationship: relationship ?? this.relationship,
    );
  }

  Map<String, dynamic> toMap(dynamic reservaId) {
    return {
      'reserva_id': reservaId,
      'full_name': fullName.trim(),
      'document_number': documentNumber.trim(),
      'document_type': documentType,
      'nationality': nationality.trim(),
      'is_adult': isAdult,
      'relationship': relationship.trim(),
    };
  }

  /// Formato legal consolidado para compatibilidad con esquemas mínimos
  String get legalDocumentSummary =>
      '$documentType: ${documentNumber.trim()} (${isAdult ? "Adulto" : "Menor"}${relationship.isNotEmpty ? " - $relationship" : ""})';

  @override
  List<Object?> get props => [
        id,
        fullName,
        documentType,
        documentNumber,
        nationality,
        isAdult,
        relationship,
      ];
}
