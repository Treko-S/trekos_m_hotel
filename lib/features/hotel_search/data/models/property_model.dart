import 'package:trekos_m_hotel/features/hotel_search/domain/entities/property.dart';

class PropertyModel extends Property {
  const PropertyModel({
    required super.id,
    required super.hostId,
    required super.title,
    required super.description,
    required super.pricePerNight,
    required super.maxGuests,
    required super.country,
    required super.city,
    required super.address,
    super.latitude,
    super.longitude,
    required super.imageUrls,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'],
      hostId: json['host_id'],
      title: json['title'],
      description: json['description'],
      pricePerNight: (json['price_per_night'] as num).toDouble(),
      maxGuests: json['max_guests'],
      country: json['country'],
      city: json['city'],
      address: json['address'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      // Mapeo para la relación con property_images si viene en el join
      imageUrls: json['property_images'] != null
          ? List<String>.from(json['property_images'].map((img) => img['image_url']))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host_id': hostId,
      'title': title,
      'description': description,
      'price_per_night': pricePerNight,
      'max_guests': maxGuests,
      'country': country,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
