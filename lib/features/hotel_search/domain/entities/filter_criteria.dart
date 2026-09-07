import 'package:equatable/equatable.dart';

class AdvancedFilterCriteria extends Equatable {
  final double minPrice;
  final double maxPrice;
  final String? roomType;
  final int minCapacity;
  final int? floor;
  final bool requireAc;
  final bool requireWifi;
  final bool requireTv;
  final bool requireMinibar;
  final bool requireJacuzzi;
  final bool requireBalcony;

  const AdvancedFilterCriteria({
    this.minPrice = 150000.0,
    this.maxPrice = 1000000.0,
    this.roomType,
    this.minCapacity = 1,
    this.floor,
    this.requireAc = false,
    this.requireWifi = false,
    this.requireTv = false,
    this.requireMinibar = false,
    this.requireJacuzzi = false,
    this.requireBalcony = false,
  });

  bool get isActive =>
      minPrice > 150000.0 ||
      maxPrice < 1000000.0 ||
      (roomType != null && roomType != 'ALL') ||
      minCapacity > 1 ||
      floor != null ||
      requireAc ||
      requireWifi ||
      requireTv ||
      requireMinibar ||
      requireJacuzzi ||
      requireBalcony;

  AdvancedFilterCriteria copyWith({
    double? minPrice,
    double? maxPrice,
    String? roomType,
    int? minCapacity,
    int? floor,
    bool? requireAc,
    bool? requireWifi,
    bool? requireTv,
    bool? requireMinibar,
    bool? requireJacuzzi,
    bool? requireBalcony,
  }) {
    return AdvancedFilterCriteria(
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      roomType: roomType ?? this.roomType,
      minCapacity: minCapacity ?? this.minCapacity,
      floor: floor ?? this.floor,
      requireAc: requireAc ?? this.requireAc,
      requireWifi: requireWifi ?? this.requireWifi,
      requireTv: requireTv ?? this.requireTv,
      requireMinibar: requireMinibar ?? this.requireMinibar,
      requireJacuzzi: requireJacuzzi ?? this.requireJacuzzi,
      requireBalcony: requireBalcony ?? this.requireBalcony,
    );
  }

  @override
  List<Object?> get props => [
        minPrice,
        maxPrice,
        roomType,
        minCapacity,
        floor,
        requireAc,
        requireWifi,
        requireTv,
        requireMinibar,
        requireJacuzzi,
        requireBalcony,
      ];
}
