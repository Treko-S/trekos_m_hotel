import 'package:equatable/equatable.dart';

class Property extends Equatable {
  final String id;
  final String hostId;
  final String title;
  final String description;
  final double pricePerNight;
  final int maxGuests;
  final String country;
  final String city;
  final String address;
  final double? latitude;
  final double? longitude;
  final List<String> imageUrls;

  const Property({
    required this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.pricePerNight,
    required this.maxGuests,
    required this.country,
    required this.city,
    required this.address,
    this.latitude,
    this.longitude,
    required this.imageUrls,
  });

  @override
  List<Object?> get props => [id, hostId, title, city, pricePerNight];
}
