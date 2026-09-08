import 'package:equatable/equatable.dart';

class CancellationEvaluation extends Equatable {
  final String bookingId;
  final String ratePlanType;
  final double hoursRemaining;
  final double totalPaid;
  final bool canCancelFree;
  final bool isPenalty;
  final double refundAmount;
  final double penaltyAmount;
  final String message;

  const CancellationEvaluation({
    required this.bookingId,
    required this.ratePlanType,
    required this.hoursRemaining,
    required this.totalPaid,
    required this.canCancelFree,
    required this.isPenalty,
    required this.refundAmount,
    required this.penaltyAmount,
    required this.message,
  });

  factory CancellationEvaluation.fromMap(Map<String, dynamic> map, {required String fallbackBookingId}) {
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return CancellationEvaluation(
      bookingId: map['reserva_id']?.toString() ?? fallbackBookingId,
      ratePlanType: map['rate_plan_type']?.toString() ?? 'Flexible',
      hoursRemaining: parseDouble(map['hours_remaining']),
      totalPaid: parseDouble(map['total_pagos']),
      canCancelFree: map['can_cancel_free'] == true,
      isPenalty: map['is_penalty'] == true,
      refundAmount: parseDouble(map['refund_amount']),
      penaltyAmount: parseDouble(map['penalty_amount']),
      message: map['message']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [
        bookingId,
        ratePlanType,
        hoursRemaining,
        totalPaid,
        canCancelFree,
        isPenalty,
        refundAmount,
        penaltyAmount,
        message,
      ];
}
