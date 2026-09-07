import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:trekos_m_hotel/core/services/payment_cards_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PaymentCardsService Tests', () {
    test('getDefaultCards genera tarjetas Visa Crédito y Mastercard Débito por defecto', () {
      final defaultCards = PaymentCardsService.getDefaultCards(defaultOwnerName: 'KEVIN SANTACRUZ');

      expect(defaultCards.length, equals(2));

      final creditCard = defaultCards.firstWhere((c) => c.type == 'Crédito');
      expect(creditCard.brand, equals('Visa'));
      expect(creditCard.isDefault, isTrue);
      expect(creditCard.last4, equals('4242'));
      expect(creditCard.cardholderName, equals('KEVIN SANTACRUZ'));

      final debitCard = defaultCards.firstWhere((c) => c.type == 'Débito');
      expect(debitCard.brand, equals('Mastercard'));
      expect(debitCard.isDefault, isFalse);
      expect(debitCard.last4, equals('8812'));
      expect(debitCard.cardholderName, equals('KEVIN SANTACRUZ'));
    });

    test('getCards inicializa y persiste tarjetas por defecto cuando el storage está vacío', () async {
      final cards = await PaymentCardsService.getCards(defaultOwnerName: 'JUAN HUÉSPED');

      expect(cards.length, equals(2));
      expect(cards.any((c) => c.isDefault), isTrue);

      final defaultCard = await PaymentCardsService.getDefaultCard(defaultOwnerName: 'JUAN HUÉSPED');
      expect(defaultCard.brand, equals('Visa'));
      expect(defaultCard.type, equals('Crédito'));
    });

    test('addCard y setDefaultCard actualizan correctamente la tarjeta predeterminada para autocarga', () async {
      await PaymentCardsService.getCards();

      final customCard = SavedPaymentCard(
        id: 'card_custom_1',
        cardholderName: 'KEVIN SANTACRUZ',
        cardNumber: '4000123456789999',
        expiry: '12/30',
        cvv: '777',
        type: 'Crédito',
        brand: 'Visa',
        isDefault: true,
      );

      await PaymentCardsService.addCard(customCard);
      final cardsAfterAdd = await PaymentCardsService.getCards();

      expect(cardsAfterAdd.length, equals(3));
      final defaultCard = await PaymentCardsService.getDefaultCard();
      expect(defaultCard.id, equals('card_custom_1'));
      expect(defaultCard.last4, equals('9999'));

      // Cambiar predeterminada a la tarjeta de débito
      await PaymentCardsService.setDefaultCard('default_card_debit_mastercard');
      final newDefault = await PaymentCardsService.getDefaultCard();
      expect(newDefault.id, equals('default_card_debit_mastercard'));
      expect(newDefault.type, equals('Débito'));
    });

    test('deleteCard elimina la tarjeta y mantiene una predeterminada válida', () async {
      await PaymentCardsService.getCards();
      await PaymentCardsService.deleteCard('default_card_credit_visa');

      final remaining = await PaymentCardsService.getCards();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('default_card_debit_mastercard'));
      expect(remaining.first.isDefault, isTrue);
    });
  });
}
