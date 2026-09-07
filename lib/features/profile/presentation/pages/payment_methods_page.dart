import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/payment_cards_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<SavedPaymentCard> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    String? ownerName;
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess && authState.user.name.trim().isNotEmpty) {
        ownerName = authState.user.name.trim().toUpperCase();
      }
    } catch (_) {}

    final loadedCards = await PaymentCardsService.getCards(defaultOwnerName: ownerName);
    if (mounted) {
      setState(() {
        _cards = loadedCards;
        _isLoading = false;
      });
    }
  }

  void _showAddCardModal() {
    final formKey = GlobalKey<FormState>();
    final numCtrl = TextEditingController();
    String defaultOwner = 'KEVIN SANTACRUZ';
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess && authState.user.name.trim().isNotEmpty) {
        defaultOwner = authState.user.name.trim().toUpperCase();
      }
    } catch (_) {}
    final nameCtrl = TextEditingController(text: defaultOwner);
    final expCtrl = TextEditingController();
    final cvvCtrl = TextEditingController();
    String selectedType = 'Crédito';
    String selectedBrand = 'Visa';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) => StatefulBuilder(
        builder: (bCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(bCtx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Agregar Tarjeta de Prueba',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyLuxury,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Simulador de tarjetas para reservas y pagos de foliatura.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Tipo de Tarjeta
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Crédito')),
                          selected: selectedType == 'Crédito',
                          onSelected: (val) => setModalState(() => selectedType = 'Crédito'),
                          selectedColor: AppTheme.navyLuxury,
                          labelStyle: TextStyle(
                            color: selectedType == 'Crédito' ? Colors.white : const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Débito')),
                          selected: selectedType == 'Débito',
                          onSelected: (val) => setModalState(() => selectedType = 'Débito'),
                          selectedColor: AppTheme.navyLuxury,
                          labelStyle: TextStyle(
                            color: selectedType == 'Débito' ? Colors.white : const Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Número de Tarjeta
                  TextFormField(
                    controller: numCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 19,
                    decoration: InputDecoration(
                      labelText: 'Número de Tarjeta (16 dígitos)',
                      hintText: '4532 8901 2345 6789',
                      prefixIcon: const Icon(Icons.credit_card_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 15) return 'Ingrese los 16 dígitos de prueba';
                      return null;
                    },
                    onChanged: (val) {
                      if (val.startsWith('4')) {
                        setModalState(() => selectedBrand = 'Visa');
                      } else if (val.startsWith('5')) {
                        setModalState(() => selectedBrand = 'Mastercard');
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Titular
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Nombre del Titular',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre del titular' : null,
                  ),
                  const SizedBox(height: 12),

                  // Fecha y CVV
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: expCtrl,
                          keyboardType: TextInputType.datetime,
                          maxLength: 5,
                          decoration: InputDecoration(
                            labelText: 'Vencimiento',
                            hintText: 'MM/AA',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            counterText: '',
                          ),
                          validator: (v) => (v == null || !v.contains('/')) ? 'MM/AA' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: cvvCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 4,
                          decoration: InputDecoration(
                            labelText: 'CVV',
                            hintText: '123',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            counterText: '',
                          ),
                          validator: (v) => (v == null || v.length < 3) ? '3 dígitos' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.navyLuxury,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final cleanNum = numCtrl.text.replaceAll(RegExp(r'\D'), '');

                        final newCard = SavedPaymentCard(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          cardholderName: nameCtrl.text.trim().toUpperCase(),
                          cardNumber: cleanNum.padRight(16, '0'),
                          expiry: expCtrl.text.trim(),
                          cvv: cvvCtrl.text.trim().isNotEmpty ? cvvCtrl.text.trim() : '123',
                          type: selectedType,
                          brand: selectedBrand,
                          isDefault: _cards.isEmpty,
                        );

                        await PaymentCardsService.addCard(newCard);
                        await _loadCards();

                        if (mounted && bCtx.mounted) {
                          Navigator.pop(bCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF4ADE80)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('Tarjeta sincronizada con éxito ($selectedBrand)'),
                                  ),
                                ],
                              ),
                              backgroundColor: AppTheme.navyLuxury,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.add_card_rounded, color: AppTheme.goldLuxury),
                      label: const Text('Guardar Tarjeta de Prueba', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
          'Métodos de Pago',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Entorno de Prueba / Simulación Académica
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Entorno de Simulación Académica UTCD: Estas tarjetas son de prueba para simular reservas y liquidaciones. No se procesan transacciones bancarias reales.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Tarjetas Guardadas (${_cards.length})',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.navyLuxury,
              ),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryBlue),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Sincronizando medios de pago...',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            else if (_cards.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.credit_card_off_rounded, size: 48, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    const Text(
                      'No tienes tarjetas agregadas',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cards.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 14),
                itemBuilder: (ctx, index) {
                  final card = _cards[index];
                  return _buildCardItem(card);
                },
              ),

            const SizedBox(height: 20),

            // Botón Agregar Tarjeta
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.navyLuxury,
                  side: const BorderSide(color: AppTheme.navyLuxury, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showAddCardModal,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar Tarjeta de Débito / Crédito', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(SavedPaymentCard card) {
    final isVisa = card.brand == 'Visa';
    final cardBgGradient = isVisa
        ? const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF831843), Color(0xFFBE185D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: cardBgGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.nfc_rounded, color: Colors.white70, size: 22),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      card.type.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              Text(
                card.brand.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            card.maskedNumber,
            style: GoogleFonts.sourceCodePro(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TITULAR', style: TextStyle(fontSize: 9, color: Colors.white60, letterSpacing: 0.8)),
                    Text(
                      card.cardholderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('VENCE', style: TextStyle(fontSize: 9, color: Colors.white60, letterSpacing: 0.8)),
                  Text(
                    card.expiry,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              if (card.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Predeterminada', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                )
              else
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) async {
                    if (action == 'default') {
                      await PaymentCardsService.setDefaultCard(card.id);
                      await _loadCards();
                    } else if (action == 'delete') {
                      await PaymentCardsService.deleteCard(card.id);
                      await _loadCards();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'default',
                      child: Text('Establecer como predeterminada', style: TextStyle(fontSize: 12.5)),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar tarjeta', style: TextStyle(fontSize: 12.5, color: Colors.red)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
