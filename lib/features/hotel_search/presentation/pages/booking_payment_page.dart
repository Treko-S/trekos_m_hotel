import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trekos_m_hotel/core/services/email_notification_service.dart';
import 'package:trekos_m_hotel/core/services/payment_cards_service.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/booking.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_state.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/pages/explore_rooms_page.dart';

enum PaymentMethodType { card, sipap, wallet }

class BookingPaymentPage extends StatefulWidget {
  final Booking booking;
  final double? suggestedAmount;

  const BookingPaymentPage({
    super.key,
    required this.booking,
    this.suggestedAmount,
  });

  @override
  State<BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends State<BookingPaymentPage> {
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

  PaymentMethodType _selectedMethod = PaymentMethodType.card;
  int _amountPresetIndex = 0; // 0: 100% total, 1: 50%, 2: 20%, 3: Monto X

  double _amountToPay = 0.0;
  final TextEditingController _customAmountController = TextEditingController();

  // Campos de Tarjeta
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();
  String _cardType = 'Crédito';

  // Tarjetas Sincronizadas
  List<SavedPaymentCard> _savedCards = [];
  SavedPaymentCard? _selectedSavedCard;
  bool _isCustomCardManual = false;
  bool _saveCardForFuture = false;
  bool _isLoadingSavedCards = true;

  // Campos de Transferencia SIPAP
  final TextEditingController _bankOriginController = TextEditingController(text: 'Banco Itaú Paraguay');
  final TextEditingController _transferRefController = TextEditingController();
  bool _isProofAttached = false;

  // Campos de Billetera Móvil
  String _walletProvider = 'Tigo Money';
  final TextEditingController _walletPhoneController = TextEditingController();
  final TextEditingController _walletTxController = TextEditingController();

  // Cupón de Descuento de Temporada (un solo uso por usuario)
  final TextEditingController _couponController = TextEditingController();
  String? _appliedCouponCode;
  double _discountPercent = 0.0;
  double _discountAmount = 0.0;
  String? _couponErrorMessage;
  String? _couponSuccessMessage;
  bool _isCheckingCoupon = false;

  final _formKey = GlobalKey<FormState>();
  bool _voucherShown = false;

  @override
  void initState() {
    super.initState();
    final pending = widget.booking.folioSaldoPendiente > 0
        ? widget.booking.folioSaldoPendiente
        : widget.booking.montoTotal;

    if (widget.suggestedAmount != null && widget.suggestedAmount! > 0) {
      _amountToPay = widget.suggestedAmount!.clamp(1.0, pending);
      _amountPresetIndex = 3;
      _customAmountController.text = currencyFormat.format(_amountToPay.round());
    } else {
      _amountToPay = pending;
      _amountPresetIndex = 0;
      _customAmountController.text = currencyFormat.format(_amountToPay.round());
    }

    // Prellenar nombre del titular de la tarjeta si el usuario está autenticado
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthSuccess) {
      _cardHolderController.text = authState.user.name.trim().isNotEmpty
          ? authState.user.name.trim().toUpperCase()
          : 'HUÉSPED TITULAR';
      _walletPhoneController.text = authState.user.phone ?? '';
    }

    // Autocargar y sincronizar tarjetas predeterminadas y guardadas
    _loadAndAutoFillPaymentMethods();
  }

  Future<void> _loadAndAutoFillPaymentMethods() async {
    String? defaultOwner;
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess && authState.user.name.trim().isNotEmpty) {
        defaultOwner = authState.user.name.trim().toUpperCase();
      }
    } catch (_) {}

    final cards = await PaymentCardsService.getCards(defaultOwnerName: defaultOwner);
    if (!mounted) return;

    setState(() {
      _savedCards = cards;
      _isLoadingSavedCards = false;

      // Autocargar de inmediato la tarjeta predeterminada si existe
      if (cards.isNotEmpty) {
        final defaultCard = cards.firstWhere((c) => c.isDefault, orElse: () => cards.first);
        _selectSavedCard(defaultCard);
      }
    });
  }

  void _selectSavedCard(SavedPaymentCard card) {
    _selectedSavedCard = card;
    _isCustomCardManual = false;
    _cardNumberController.text = card.formattedNumber;
    _cardHolderController.text = card.cardholderName;
    _cardExpiryController.text = card.expiry;
    _cardCvvController.text = card.cvv;
    _cardType = card.type;
  }

  void _selectManualNewCard() {
    _selectedSavedCard = null;
    _isCustomCardManual = true;
    _cardNumberController.clear();
    _cardExpiryController.clear();
    _cardCvvController.clear();
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthSuccess && authState.user.name.trim().isNotEmpty) {
        _cardHolderController.text = authState.user.name.trim().toUpperCase();
      } else {
        _cardHolderController.clear();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _couponController.dispose();
    _customAmountController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _bankOriginController.dispose();
    _transferRefController.dispose();
    _walletPhoneController.dispose();
    _walletTxController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _couponErrorMessage = 'Por favor ingresa un código de descuento.';
        _couponSuccessMessage = null;
      });
      return;
    }

    setState(() {
      _isCheckingCoupon = true;
      _couponErrorMessage = null;
      _couponSuccessMessage = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      String userId = '';
      if (authState is AuthSuccess) {
        userId = authState.user.id;
      } else {
        userId = Supabase.instance.client.auth.currentUser?.id ?? widget.booking.guestId;
      }

      if (userId.isEmpty) {
        userId = 'guest_user';
      }

      const storage = FlutterSecureStorage();
      final usageKey = 'coupon_used_${code}_$userId';
      final alreadyUsed = await storage.read(key: usageKey);

      if (alreadyUsed == 'true') {
        setState(() {
          _isCheckingCoupon = false;
          _couponErrorMessage = 'El código "$code" ya ha sido canjeado por tu cuenta. Es de un solo uso por usuario.';
          _couponSuccessMessage = null;
        });
        return;
      }

      // Validar códigos activos (VERANO2026, PROMO2026, UTCD2026)
      if (code == 'VERANO2026' || code == 'PROMO2026' || code == 'UTCD2026') {
        final percent = 0.20; // 20% de descuento sobre el total de estadía
        final totalStay = widget.booking.montoTotal > 0
            ? widget.booking.montoTotal
            : (widget.booking.folioSaldoPendiente > 0 ? widget.booking.folioSaldoPendiente : 720000.0);
        final discount = (totalStay * percent).roundToDouble();
        final discountedTotal = (totalStay - discount).clamp(0.0, double.infinity);

        setState(() {
          _appliedCouponCode = code;
          _discountPercent = percent;
          _discountAmount = discount;

          if (_amountPresetIndex == 0) {
            _amountToPay = discountedTotal;
          } else if (_amountPresetIndex == 1) {
            _amountToPay = (discountedTotal * 0.50).roundToDouble();
          } else if (_amountPresetIndex == 2) {
            _amountToPay = (discountedTotal * 0.20).roundToDouble();
          } else {
            _amountToPay = _amountToPay.clamp(0.0, discountedTotal);
          }

          _customAmountController.text = currencyFormat.format(_amountToPay.round());
          _couponSuccessMessage = '¡Código $code canjeado con éxito! 20% de descuento aplicado (-${currencyFormat.format(discount)} Gs.).';
          _couponErrorMessage = null;
          _isCheckingCoupon = false;
        });
      } else {
        setState(() {
          _isCheckingCoupon = false;
          _couponErrorMessage = 'Código de descuento no válido o expirado. Prueba con "VERANO2026".';
          _couponSuccessMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _isCheckingCoupon = false;
        _couponErrorMessage = 'Error al validar cupón: $e';
      });
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _discountPercent = 0.0;
      _discountAmount = 0.0;
      _couponSuccessMessage = null;
      _couponErrorMessage = null;
      _couponController.clear();

      final pending = widget.booking.folioSaldoPendiente > 0
          ? widget.booking.folioSaldoPendiente
          : widget.booking.montoTotal;

      if (_amountPresetIndex == 0) {
        _amountToPay = pending;
      } else if (_amountPresetIndex == 1) {
        _amountToPay = (pending * 0.50).roundToDouble();
      } else if (_amountPresetIndex == 2) {
        _amountToPay = (pending * 0.20).roundToDouble();
      }
      _customAmountController.text = currencyFormat.format(_amountToPay.round());
    });
  }

  void _onPresetChanged(int index) {
    final originalTotal = widget.booking.folioSaldoPendiente > 0
        ? widget.booking.folioSaldoPendiente
        : widget.booking.montoTotal;
    final base = _discountAmount > 0
        ? (originalTotal - _discountAmount).clamp(0.0, double.infinity)
        : originalTotal;

    setState(() {
      _amountPresetIndex = index;
      if (index == 0) {
        _amountToPay = base;
      } else if (index == 1) {
        _amountToPay = (base * 0.50).roundToDouble();
      } else if (index == 2) {
        _amountToPay = (base * 0.20).roundToDouble();
      }
      _customAmountController.text = currencyFormat.format(_amountToPay.round());
    });
  }

  void _onCustomAmountChanged(String val) {
    final clean = val.replaceAll('.', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(clean) ?? 0.0;
    final originalTotal = widget.booking.folioSaldoPendiente > 0
        ? widget.booking.folioSaldoPendiente
        : widget.booking.montoTotal;
    final maxAllowed = _discountAmount > 0
        ? (originalTotal - _discountAmount).clamp(0.0, double.infinity)
        : originalTotal;

    setState(() {
      _amountToPay = parsed.clamp(0.0, maxAllowed);
    });
  }

  void _processPayment() {
    if (_amountToPay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('El monto a abonar debe ser mayor a 0 Gs.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validaciones mínimas según método
    if (_selectedMethod == PaymentMethodType.card) {
      final cleanCard = _cardNumberController.text.replaceAll(' ', '');
      if (cleanCard.length < 15 && !cleanCard.contains('•')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor ingresa un número de tarjeta válido (16 dígitos).'),
            backgroundColor: Colors.amber.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_cardCvvController.text.trim().length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ingresa el código de seguridad CVV (3 o 4 dígitos).'),
            backgroundColor: Colors.amber.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Sincronizar nueva tarjeta si el usuario eligió guardarla
      if (_isCustomCardManual && _saveCardForFuture) {
        final brand = cleanCard.startsWith('5')
            ? 'Mastercard'
            : (cleanCard.startsWith('3') ? 'American Express' : 'Visa');
        final newCard = SavedPaymentCard(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          cardholderName: _cardHolderController.text.trim().toUpperCase(),
          cardNumber: cleanCard.padRight(16, '0'),
          expiry: _cardExpiryController.text.trim(),
          cvv: _cardCvvController.text.trim(),
          type: _cardType,
          brand: brand,
          isDefault: false,
        );
        PaymentCardsService.addCard(newCard);
      }
    } else if (_selectedMethod == PaymentMethodType.sipap) {
      if (_transferRefController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor ingresa el número de referencia de la transferencia SIPAP.'),
            backgroundColor: Colors.amber.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else if (_selectedMethod == PaymentMethodType.wallet) {
      if (_walletPhoneController.text.trim().isEmpty || _walletTxController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Por favor ingresa el número telefónico y el código de giro/transacción.'),
            backgroundColor: Colors.amber.shade900,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final folioId = widget.booking.folioId ?? '';
    final bookingId = widget.booking.id;
    final guestId = widget.booking.guestId;

    String methodName = 'Tarjeta de ${_cardType.capitalize()}';
    String ref = 'Trx Simulado Card ***${_cardNumberController.text.length >= 4 ? _cardNumberController.text.substring(_cardNumberController.text.length - 4) : "0000"}';

    if (_selectedMethod == PaymentMethodType.sipap) {
      methodName = 'Transferencia SIPAP (${_bankOriginController.text.trim()})';
      ref = 'Ref: ${_transferRefController.text.trim()}';
    } else if (_selectedMethod == PaymentMethodType.wallet) {
      methodName = 'Billetera Móvil ($_walletProvider)';
      ref = 'Línea: ${_walletPhoneController.text.trim()} - ID: ${_walletTxController.text.trim()}';
    }

    if (_appliedCouponCode != null) {
      ref += ' [Cupón: $_appliedCouponCode (-20%)]';
      final authState = context.read<AuthBloc>().state;
      final userId = authState is AuthSuccess ? authState.user.id : (Supabase.instance.client.auth.currentUser?.id ?? widget.booking.guestId);
      const FlutterSecureStorage().write(key: 'coupon_used_${_appliedCouponCode}_$userId', value: 'true');
    }

    context.read<HotelBloc>().add(
          HotelRegisterPaymentRequested(
            folioId: folioId,
            bookingId: bookingId,
            amount: _amountToPay,
            paymentMethod: methodName,
            reference: ref,
            guestId: guestId,
            discountAmount: _discountAmount,
            couponCode: _appliedCouponCode,
          ),
        );
  }

  void _navigateToMyBookings() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const ExploreRoomsPage(initialNavIndex: 1),
      ),
      (route) => false,
    );
  }

  void _showPaymentSuccessVoucher(BuildContext context, double amountPaid) {
    if (_voucherShown) return;
    _voucherShown = true;

    final voucherCode = 'TRX-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final totalStay = widget.booking.montoTotal > 0 ? widget.booking.montoTotal : widget.booking.folioSaldoPendiente;
    final effectiveTotal = _discountAmount > 0 ? (totalStay - _discountAmount).clamp(0.0, double.infinity) : totalStay;
    final remainingBalance = (effectiveTotal - amountPaid).clamp(0.0, double.infinity);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = dateFormat.format(DateTime.now());

    // Obtener datos del usuario autenticado para el comprobante por correo
    final authState = context.read<AuthBloc>().state;
    String recipientEmail = 'rc652107@gmail.com';
    String guestName = 'Huésped';
    if (authState is AuthSuccess) {
      recipientEmail = authState.user.email;
      guestName = authState.user.name;
    }

    final methodName = _selectedMethod == PaymentMethodType.card
        ? 'Tarjeta de $_cardType'
        : _selectedMethod == PaymentMethodType.sipap
            ? 'Transferencia SIPAP'
            : 'Billetera Móvil';

    // Disparo automático de comprobante oficial mediante Brevo API
    EmailNotificationService.sendPaymentReceipt(
      recipientEmail: recipientEmail,
      guestName: guestName,
      bookingCode: widget.booking.codigoReserva,
      roomNumber: widget.booking.habitacionNumero,
      totalAmount: widget.booking.montoTotal,
      paidAmount: amountPaid,
      remainingAmount: remainingBalance,
      paymentMethod: methodName,
      transactionRef: voucherCode,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge de éxito
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 42),
              ),
              const SizedBox(height: 16),
              Text(
                '¡Abono Registrado!',
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navyLuxury,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Comprobante Digital Oficial',
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),

              // Caja de Comprobante / Voucher
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildVoucherRow('N° de Operación:', voucherCode, isBold: true),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildVoucherRow('Reserva:', widget.booking.codigoReserva),
                    const SizedBox(height: 4),
                    _buildVoucherRow('Habitación:', '${widget.booking.habitacionNumero} (${widget.booking.habitacionTipo})'),
                    const SizedBox(height: 4),
                    _buildVoucherRow('Fecha:', formattedDate),
                    const SizedBox(height: 4),
                    _buildVoucherRow('Método:', methodName),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildVoucherRow(
                      'Monto Abonado:',
                      '${currencyFormat.format(amountPaid)} Gs.',
                      color: const Color(0xFF10B981),
                      isBold: true,
                    ),
                    const SizedBox(height: 4),
                    _buildVoucherRow(
                      'Saldo Restante:',
                      remainingBalance <= 0 ? 'PAGADO TOTAL (0 Gs.)' : '${currencyFormat.format(remainingBalance)} Gs.',
                      color: remainingBalance <= 0 ? const Color(0xFF10B981) : AppTheme.navyLuxury,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Indicador de Comprobante por Correo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Comprobante enviado a: $recipientEmail',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'Tu saldo de cuenta ha sido actualizado en tiempo real. Podrás consultar tu Folio en "Mis Reservas".',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyLuxury,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _navigateToMyBookings();
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.goldLuxury),
                  label: const Text('Ir a Mis Reservas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppTheme.navyLuxury,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final originalPending = widget.booking.folioSaldoPendiente > 0
        ? widget.booking.folioSaldoPendiente
        : widget.booking.montoTotal;

    final effectivePending = _discountAmount > 0
        ? (originalPending - _discountAmount).clamp(0.0, double.infinity)
        : originalPending;

    final pendingBalance = effectivePending;
    final newRemaining = (effectivePending - _amountToPay).clamp(0.0, double.infinity);

    return BlocListener<HotelBloc, HotelState>(
      listener: (context, state) {
        if (state.paymentErrorMessage != null && !state.isSubmittingPayment) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.paymentErrorMessage!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        if (state.paymentSuccess == true && !state.isSubmittingPayment) {
          _showPaymentSuccessVoucher(context, _amountToPay);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: AppTheme.navyLuxury,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Abono de Reserva',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () {
              _showExitConfirmationDialog();
            },
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. TARJETA RESUMEN DE LA RESERVA
                        _buildBookingSummaryCard(pendingBalance),

                        const SizedBox(height: 20),

                        // 2. SELECTOR DE MONTO A ABONAR
                        _buildAmountSelectionSection(pendingBalance, newRemaining),

                        const SizedBox(height: 20),

                        // CUPÓN / CÓDIGO DE DESCUENTO DE TEMPORADA
                        _buildDiscountCouponSection(),

                        const SizedBox(height: 24),

                        // 3. SELECTOR DE MÉTODO DE PAGO
                        _buildPaymentMethodSelector(),

                        const SizedBox(height: 20),

                        // 4. FORMULARIO ESPECÍFICO SEGÚN MÉTODO
                        if (_selectedMethod == PaymentMethodType.card)
                          _buildCardPaymentSection()
                        else if (_selectedMethod == PaymentMethodType.sipap)
                          _buildSipapPaymentSection()
                        else
                          _buildWalletPaymentSection(),

                        const SizedBox(height: 20),

                        // 5. AVISO DE ENTORNO DEMOSTRATIVO
                        _buildDemoNoticeBadge(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // BARRA INFERIOR STICKY CON BOTÓN DE ACCIÓN
              _buildBottomActionSection(pendingBalance),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingSummaryCard(double pendingBalance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_added_rounded, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.booking.codigoReserva,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyLuxury),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Hab. ${widget.booking.habitacionNumero}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.booking.habitacionTipo,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Estadía:', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${currencyFormat.format(widget.booking.montoTotal)} Gs.',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Saldo Actual a Pagar:', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${currencyFormat.format(pendingBalance)} Gs.',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSelectionSection(double pendingBalance, double newRemaining) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.monetization_on_outlined, size: 20, color: AppTheme.goldLuxury),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿Cuánto deseas abonar?',
                style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Chips de Opciones Rápidas
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('Total (100%)', 0),
              const SizedBox(width: 8),
              _buildPresetChip('50% Anticipo', 1),
              const SizedBox(width: 8),
              _buildPresetChip('20% Mínimo', 2),
              const SizedBox(width: 8),
              _buildPresetChip('Otro Monto (X)', 3),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Campo interactivo de monto
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _amountPresetIndex == 3 ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
              width: _amountPresetIndex == 3 ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Monto a transferir:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_amountPresetIndex != 3)
                    Text(
                      'Modo automático',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                    )
                  else
                    const Text(
                      'Personalizado',
                      style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Gs.',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navyLuxury,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _customAmountController,
                      enabled: _amountPresetIndex == 3,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyLuxury,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: '0',
                      ),
                      onChanged: _onCustomAmountChanged,
                    ),
                  ),
                  if (_amountPresetIndex == 3)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => _onPresetChanged(0),
                      child: const Text('Pagar Todo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Saldo restante:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      newRemaining <= 0 ? '0 Gs. (Saldado)' : '${currencyFormat.format(newRemaining)} Gs.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: newRemaining <= 0 ? const Color(0xFF10B981) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountCouponSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _appliedCouponCode != null ? const Color(0xFF10B981) : AppTheme.goldLuxury.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, size: 20, color: AppTheme.goldLuxury),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cupón de Descuento de Temporada',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.navyLuxury),
                ),
              ),
              if (_appliedCouponCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-${(_discountPercent * 100).round()}% APLICADO',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa un código promocional de temporada. Válido exclusivamente para pagos en la app y limitado a un solo uso por usuario.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 12),

          if (_appliedCouponCode == null) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _couponController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Ej: VERANO2026',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isCheckingCoupon ? null : _applyCoupon,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyLuxury,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                    ),
                    child: _isCheckingCoupon
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Canjear', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cupón Activo: $_appliedCouponCode',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ahorro del 20%: -${currencyFormat.format(_discountAmount)} Gs.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _removeCoupon,
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFB91C1C)),
                    label: const Text('Quitar', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          if (_couponErrorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _couponErrorMessage!,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_couponSuccessMessage != null && _appliedCouponCode != null) ...[
            const SizedBox(height: 8),
            Text(
              _couponSuccessMessage!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF166534), fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, int index) {
    final isSelected = _amountPresetIndex == index;
    return InkWell(
      onTap: () => _onPresetChanged(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navyLuxury : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.navyLuxury : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppTheme.goldLuxury),
            const SizedBox(width: 8),
            Text(
              'Método de Pago',
              style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyLuxury),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMethodTab(
                type: PaymentMethodType.card,
                title: 'Tarjeta',
                icon: Icons.credit_card_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMethodTab(
                type: PaymentMethodType.sipap,
                title: 'SIPAP',
                icon: Icons.account_balance_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMethodTab(
                type: PaymentMethodType.wallet,
                title: 'Billetera',
                icon: Icons.phone_android_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMethodTab({
    required PaymentMethodType type,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == type;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = type),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navyLuxury : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.navyLuxury : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.navyLuxury.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3))]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: isSelected ? AppTheme.goldLuxury : const Color(0xFF64748B)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECCIÓN A: TARJETA DE CRÉDITO / DÉBITO
  // ==========================================
  Widget _buildCardPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SELECTOR RÁPIDO DE MEDIOS DE PAGO SINCRONIZADOS
        _buildSavedCardsSelector(),

        const SizedBox(height: 18),

        // 1. TARJETA VIRTUAL INTERACTIVA
        _buildVirtualCard(),

        const SizedBox(height: 18),

        // Tipo Débito / Crédito Selector
        Builder(
          builder: (context) {
            final isSaved = !_isCustomCardManual && _selectedSavedCard != null;
            final isCredit = _cardType.toLowerCase().contains('crédito') || _cardType.toLowerCase().contains('credito');
            final isDebit = _cardType.toLowerCase().contains('débito') || _cardType.toLowerCase().contains('debito');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: isSaved && isCredit
                            ? const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF0369A1))
                            : null,
                        label: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Tarjeta de Crédito'),
                                if (isSaved && isCredit) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Fija',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        selected: isCredit,
                        onSelected: (val) {
                          if (isSaved) {
                            if (!isCredit) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Esta tarjeta está registrada como ${_selectedSavedCard!.type} (${_selectedSavedCard!.brand}). Para pagar con Crédito, selecciona tu tarjeta de crédito arriba o pulsa "Otra Tarjeta".',
                                  ),
                                  backgroundColor: AppTheme.navyLuxury,
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            return;
                          }
                          setState(() => _cardType = 'Crédito');
                        },
                        selectedColor: const Color(0xFFE0F2FE),
                        disabledColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isCredit
                              ? const Color(0xFF0369A1)
                              : (isSaved ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        avatar: isSaved && isDebit
                            ? const Icon(Icons.lock_rounded, size: 14, color: Color(0xFF0369A1))
                            : null,
                        label: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Tarjeta de Débito'),
                                if (isSaved && isDebit) ...[
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Fija',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        selected: isDebit,
                        onSelected: (val) {
                          if (isSaved) {
                            if (!isDebit) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Esta tarjeta está registrada como ${_selectedSavedCard!.type} (${_selectedSavedCard!.brand}). Para pagar con Débito, selecciona tu tarjeta de débito arriba o pulsa "Otra Tarjeta".',
                                  ),
                                  backgroundColor: AppTheme.navyLuxury,
                                  duration: const Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            return;
                          }
                          setState(() => _cardType = 'Débito');
                        },
                        selectedColor: const Color(0xFFE0F2FE),
                        disabledColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDebit
                              ? const Color(0xFF0369A1)
                              : (isSaved ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (isSaved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: AppTheme.primaryBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tipo inmutable: Tarjeta de ${_selectedSavedCard!.type} (${_selectedSavedCard!.brand}). Asignado por el emisor de este medio guardado.',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), height: 1.25),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Indica si tu nueva tarjeta es de Crédito o Débito según corresponda.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ),
              ],
            );
          },
        ),

        const SizedBox(height: 14),

        // Número de Tarjeta
        _buildInputField(
          controller: _cardNumberController,
          label: 'Número de Tarjeta',
          hint: '4532 0000 0000 0000',
          icon: Icons.credit_card_outlined,
          keyboardType: TextInputType.number,
          readOnly: !_isCustomCardManual,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
            _CardNumberInputFormatter(),
          ],
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 12),

        // Titular
        _buildInputField(
          controller: _cardHolderController,
          label: 'Nombre y Apellido del Titular',
          hint: 'JUAN PÉREZ',
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.characters,
          readOnly: !_isCustomCardManual,
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: 12),

        // Vencimiento y CVV
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _cardExpiryController,
                label: 'Vencimiento',
                hint: 'MM/AA',
                icon: Icons.date_range_outlined,
                keyboardType: TextInputType.number,
                readOnly: !_isCustomCardManual,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  _CardExpiryInputFormatter(),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                controller: _cardCvvController,
                label: 'Código CVV',
                hint: '123',
                icon: Icons.lock_outline_rounded,
                keyboardType: TextInputType.number,
                obscureText: true,
                readOnly: !_isCustomCardManual,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),

        // Checkbox para guardar tarjeta si se ingresa manualmente
        if (_isCustomCardManual) ...[
          const SizedBox(height: 10),
          Material(
            color: const Color(0xFFF1F5F9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: CheckboxListTile(
              value: _saveCardForFuture,
              onChanged: (val) => setState(() => _saveCardForFuture = val ?? false),
              title: const Text(
                'Guardar tarjeta para futuros abonos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.navyLuxury),
              ),
              subtitle: const Text(
                'Se sincronizará en tu perfil de Trekos M Hotel automáticamente.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppTheme.navyLuxury,
            ),
          ),
        ),
        ],
      ],
    );
  }

  Widget _buildSavedCardsSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.credit_score_rounded, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Medios de Pago Guardados',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppTheme.navyLuxury,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text(
                      'Autocargado',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecciona una tarjeta sincronizada para llenar los datos de abono al instante:',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          if (_isLoadingSavedCards)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._savedCards.map((card) {
                    final isSelected = !_isCustomCardManual && _selectedSavedCard?.id == card.id;
                    final isVisa = card.isVisa;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectSavedCard(card);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isVisa ? const Color(0xFF0F172A) : const Color(0xFF831843))
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.goldLuxury : const Color(0xFFCBD5E1),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (isVisa ? const Color(0xFF0F172A) : const Color(0xFF831843))
                                          .withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVisa ? Icons.credit_card_rounded : Icons.credit_card_outlined,
                                size: 18,
                                color: isSelected ? AppTheme.goldLuxury : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${card.brand} ${card.type}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : AppTheme.navyLuxury,
                                        ),
                                      ),
                                      if (card.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'DEFAULT',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.black : const Color(0xFF92400E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    card.maskedNumber,
                                    style: GoogleFonts.sourceCodePro(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white70 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Opción de Nueva Tarjeta Manual
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectManualNewCard();
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isCustomCardManual ? AppTheme.navyLuxury : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isCustomCardManual ? AppTheme.goldLuxury : const Color(0xFFCBD5E1),
                          width: _isCustomCardManual ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_card_rounded,
                            size: 16,
                            color: _isCustomCardManual ? AppTheme.goldLuxury : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Otra Tarjeta',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _isCustomCardManual ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVirtualCard() {
    final isMastercard = (_selectedSavedCard?.isMastercard == true) ||
        _cardNumberController.text.replaceAll(' ', '').startsWith('5');
    final cardBrand = _selectedSavedCard?.brand.toUpperCase() ??
        (isMastercard ? 'MASTERCARD' : 'VISA');

    final cardNumber = _cardNumberController.text.isEmpty
        ? '•••• •••• •••• ••••'
        : (_selectedSavedCard != null && _selectedSavedCard!.formattedNumber == _cardNumberController.text
            ? _selectedSavedCard!.maskedNumber
            : _cardNumberController.text);
    final cardHolder = _cardHolderController.text.isEmpty
        ? 'TITULAR DE LA TARJETA'
        : _cardHolderController.text.toUpperCase();
    final expiry = _cardExpiryController.text.isEmpty ? 'MM/AA' : _cardExpiryController.text;

    final cardBgGradient = isMastercard
        ? const LinearGradient(
            colors: [Color(0xFF831843), Color(0xFF9D174D), Color(0xFF701A75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Container(
      width: double.infinity,
      height: 185,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: cardBgGradient,
        boxShadow: [
          BoxShadow(
            color: (isMastercard ? const Color(0xFF831843) : Colors.black).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.nfc_rounded, color: Colors.white70, size: 24),
                  SizedBox(width: 8),
                  Text('Trekos Pay', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cardBrand,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    _cardType.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: AppTheme.goldLuxury,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Chip dorado
          Container(
            width: 38,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white24),
            ),
          ),

          // Número
          Text(
            cardNumber,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              letterSpacing: 2.2,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Titular y Vencimiento
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TITULAR', style: TextStyle(color: Colors.white54, fontSize: 8.5)),
                    Text(
                      cardHolder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('EXPIRA', style: TextStyle(color: Colors.white54, fontSize: 8.5)),
                  Text(
                    expiry,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECCIÓN B: TRANSFERENCIA BANCARIA SIPAP
  // ==========================================
  Widget _buildSipapPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Datos bancarios oficiales del hotel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: const [
                        Icon(Icons.account_balance_rounded, size: 20, color: AppTheme.primaryBlue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cuenta Oficial Hotel Trekos M',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryBlue),
                    tooltip: 'Copiar todos los datos',
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(
                        text: 'Banco: Continental\nTitular: Trekos M Hotel S.A.\nRUC: 80098765-4\nCuenta: 01-2345678-01\nTipo: Cuenta Corriente',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Datos bancarios copiados al portapapeles'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 12, color: Color(0xFFDBEAFE)),
              _buildBankInfoLine('Banco:', 'Banco Continental S.A.E.C.A.'),
              _buildBankInfoLine('Titular:', 'Trekos M Hotel S.A.'),
              _buildBankInfoLine('RUC / Identificación:', '80098765-4'),
              _buildBankInfoLine('Tipo de Cuenta:', 'Cuenta Corriente en Gs.'),
              _buildBankInfoLine('Número de Cuenta:', '01-2345678-01', isSelectable: true),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _buildInputField(
          controller: _bankOriginController,
          label: 'Banco o Entidad de Origen',
          hint: 'Ej: Banco Itaú, Ueno Bank, etc.',
          icon: Icons.account_balance_outlined,
        ),

        const SizedBox(height: 12),

        _buildInputField(
          controller: _transferRefController,
          label: 'Número de Operación / Comprobante SIPAP',
          hint: 'Ej: 94827103',
          icon: Icons.confirmation_number_outlined,
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 12),

        // Adjuntar comprobante simulado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _isProofAttached ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                      color: _isProofAttached ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isProofAttached ? 'Comprobante_SIPAP.pdf' : 'Adjuntar Comprobante (Opcional)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _isProofAttached ? const Color(0xFF10B981) : AppTheme.navyLuxury,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _isProofAttached ? 'Adjunto simulado exitosamente' : 'Carga imagen o PDF de tu transferencia',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () {
                  setState(() => _isProofAttached = !_isProofAttached);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isProofAttached ? 'Comprobante simulado adjuntado' : 'Comprobante removido'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(_isProofAttached ? 'Quitar' : 'Cargar', style: const TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankInfoLine(String label, String value, {bool isSelectable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelectable ? AppTheme.primaryBlue : const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECCIÓN C: BILLETERA MÓVIL / GIROS
  // ==========================================
  Widget _buildWalletPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: const [
              Icon(Icons.phone_iphone_rounded, color: Color(0xFFD97706), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Línea Comercial Hotel: 0981 123 456\nTitular: Trekos M Hotel S.A.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Proveedor de Billetera
        DropdownButtonFormField<String>(
          initialValue: _walletProvider,
          decoration: InputDecoration(
            labelText: 'Proveedor de Billetera',
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: const [
            DropdownMenuItem(value: 'Tigo Money', child: Text('Tigo Money')),
            DropdownMenuItem(value: 'Personal Pay', child: Text('Billetera Personal Pay')),
            DropdownMenuItem(value: 'Zimple', child: Text('Billetera Zimple')),
          ],
          onChanged: (val) => setState(() => _walletProvider = val ?? 'Tigo Money'),
        ),

        const SizedBox(height: 12),

        _buildInputField(
          controller: _walletPhoneController,
          label: 'Teléfono Remitente (desde donde pagas)',
          hint: '0981 234 567',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 12),

        _buildInputField(
          controller: _walletTxController,
          label: 'Código o N° de Transacción',
          hint: 'Ej: TM-839210',
          icon: Icons.pin_outlined,
        ),
      ],
    );
  }

  // ==========================================
  // WIDGETS AUXILIARES
  // ==========================================
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscureText = false,
    bool readOnly = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: readOnly ? const Color(0xFF475569) : AppTheme.navyLuxury,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        suffixIcon: readOnly
            ? const Tooltip(
                message: 'Medio sincronizado seguro',
                child: Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
              )
            : null,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: readOnly ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: readOnly ? const Color(0xFFCBD5E1) : AppTheme.primaryBlue,
            width: readOnly ? 1.0 : 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDemoNoticeBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.shield_outlined, size: 18, color: Color(0xFF475569)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Modo Demostración Activo: Esta pasarela opera como un entorno de pago simulado. No se efectuarán cargos bancarios reales.',
              style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionSection(double pendingBalance) {
    return BlocBuilder<HotelBloc, HotelState>(
      builder: (context, state) {
        final isSubmitting = state.isSubmittingPayment;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.navyLuxury,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  onPressed: isSubmitting ? null : _processPayment,
                  child: isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Procesando Pago Seguro...', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_rounded, size: 18, color: AppTheme.goldLuxury),
                              const SizedBox(width: 8),
                              Text(
                                'Abonar ${currencyFormat.format(_amountToPay.round())} Gs. Ahora',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isSubmitting ? null : _navigateToMyBookings,
                child: const Text(
                  'Prefiero pagar en el hotel (Ir a Mis Reservas)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Deseas salir del pago?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Tu reserva ya se encuentra asegurada. Puedes abonar en cualquier momento o pagar directamente al llegar al hotel en la recepción.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuar Abonando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.navyLuxury),
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToMyBookings();
            },
            child: const Text('Ir a Mis Reservas'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// FORMATEADORES DE ENTRADA (FORMATTERS)
// ==========================================
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }
    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) {
        buffer.write('/');
      }
    }
    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
