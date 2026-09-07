import 'package:flutter_test/flutter_test.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/companion_guest.dart';

void main() {
  group('CompanionGuest Entity Tests (Registro Legal)', () {
    test('isComplete retorna false cuando faltan nombre o documento', () {
      const comp1 = CompanionGuest(id: 'c1', fullName: '', documentNumber: '');
      expect(comp1.isComplete, isFalse);

      const comp2 = CompanionGuest(id: 'c2', fullName: 'Juan Pérez', documentNumber: '');
      expect(comp2.isComplete, isFalse);

      const comp3 = CompanionGuest(id: 'c3', fullName: '', documentNumber: '1234567');
      expect(comp3.isComplete, isFalse);
    });

    test('isComplete retorna true cuando nombre y documento están presentes', () {
      const comp = CompanionGuest(
        id: 'c1',
        fullName: 'María González',
        documentType: 'CI',
        documentNumber: '4567890',
        nationality: 'Paraguaya',
        isAdult: true,
        relationship: 'Cónyuge / Pareja',
      );
      expect(comp.isComplete, isTrue);
    });

    test('legalDocumentSummary formatea correctamente datos de adulto y menor', () {
      const adultComp = CompanionGuest(
        id: 'c1',
        fullName: 'Carlos Gómez',
        documentType: 'CI',
        documentNumber: '3456789',
        isAdult: true,
        relationship: 'Amigo/a',
      );
      expect(adultComp.legalDocumentSummary, 'CI: 3456789 (Adulto - Amigo/a)');

      const childComp = CompanionGuest(
        id: 'c2',
        fullName: 'Lucas Gómez',
        documentType: 'Partida de Nacimiento',
        documentNumber: 'ACTA-9876',
        isAdult: false,
        relationship: 'Hijo/a',
      );
      expect(childComp.legalDocumentSummary, 'Partida de Nacimiento: ACTA-9876 (Menor - Hijo/a)');
    });

    test('toMap serializa todos los campos requeridos para Supabase', () {
      const comp = CompanionGuest(
        id: 'c1',
        fullName: 'Ana Martínez',
        documentType: 'Pasaporte',
        documentNumber: 'PA123456',
        nationality: 'Argentina',
        isAdult: true,
        relationship: 'Colega de Trabajo',
      );

      final map = comp.toMap(42);
      expect(map['reserva_id'], 42);
      expect(map['full_name'], 'Ana Martínez');
      expect(map['document_number'], 'PA123456');
      expect(map['document_type'], 'Pasaporte');
      expect(map['nationality'], 'Argentina');
      expect(map['is_adult'], isTrue);
      expect(map['relationship'], 'Colega de Trabajo');
    });
  });
}
