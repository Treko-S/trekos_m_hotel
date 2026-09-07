import 'dart:convert';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/room.dart';

class RoomModel extends Room {
  const RoomModel({
    required super.id,
    required super.numero,
    required super.tipoId,
    required super.tipoNombre,
    required super.tipoDescripcion,
    required super.capacidad,
    required super.precioBase,
    required super.piso,
    required super.estado,
    required super.caracteristicas,
    super.observaciones,
    super.imagenCover,
    super.imagenes = const [],
    super.fechaDisponibleDesde,
    super.bookedRanges = const [],
  });

  factory RoomModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = Map<String, dynamic>.from(rawJson);
    final tipoRaw = json['tipos_habitacion'];
    final tipo = tipoRaw is Map ? Map<String, dynamic>.from(tipoRaw) : <String, dynamic>{};
    final tipoId = json['tipo_id'] ?? 1;

    // Extraer mapa de características de forma ultra robusta
    Map<String, dynamic> caracMap = {};
    if (json['caracteristicas'] is Map) {
      caracMap = Map<String, dynamic>.from(json['caracteristicas'] as Map);
    } else if (json['caracteristicas'] is String && (json['caracteristicas'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(json['caracteristicas'] as String);
        if (decoded is Map) {
          caracMap = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    // Galería de imágenes: priorizar las cargadas en Supabase Storage / BD
    List<String> imageGallery = [];
    final rawImgs = json['imagenes'] ?? caracMap['imagenes'];
    if (rawImgs is List && rawImgs.isNotEmpty) {
      imageGallery = rawImgs
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty && (s.startsWith('http://') || s.startsWith('https://')))
          .toList();
    }

    if (imageGallery.isEmpty) {
      if (tipo['imagen_cover'] != null && tipo['imagen_cover'].toString().trim().isNotEmpty) {
        imageGallery = [tipo['imagen_cover'].toString().trim()];
      } else if (tipoId == 3) {
        // Suite Presidencial UTCD
        imageGallery = [
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
          'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800',
          'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
        ];
      } else if (tipoId == 2) {
        // Doble Superior
        imageGallery = [
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
          'https://images.unsplash.com/photo-1566665797739-1674de7a421a?w=800',
          'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=800',
          'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800',
        ];
      } else {
        // Standard Single
        imageGallery = [
          'https://images.unsplash.com/photo-1618773928121-c32242e63f39?w=800',
          'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800',
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?w=800',
        ];
      }
    }

    final String cover = imageGallery.isNotEmpty
        ? imageGallery.first
        : (tipo['imagen_cover']?.toString() ??
            'https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800');

    // Procesar reservas para obtener rangos ocupados y disponibilidad real
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<RoomBookedRange> bookedRanges = [];
    DateTime? activeCheckOutDate;
    bool isOccupiedToday = false;

    void processBooking(dynamic item) {
      if (item is! Map) return;
      final st = (item['estado'] ?? '').toString().toLowerCase().trim();
      if (st == 'confirmada' || st == 'check-in' || st == 'en curso' || st == 'ocupada' || st == 'en estadía') {
        final checkInStr = (item['check_in_previsto'] ?? item['check_in'])?.toString();
        final checkOutStr = (item['check_out_previsto'] ?? item['check_out'])?.toString();
        if (checkInStr != null && checkOutStr != null) {
          final pIn = DateTime.tryParse(checkInStr);
          final pOut = DateTime.tryParse(checkOutStr);
          if (pIn != null && pOut != null) {
            bookedRanges.add(RoomBookedRange(
              checkIn: pIn,
              checkOut: pOut,
              codigoReserva: item['codigo_reserva']?.toString(),
              estado: item['estado']?.toString(),
            ));

            final startDay = DateTime(pIn.year, pIn.month, pIn.day);
            final endDay = DateTime(pOut.year, pOut.month, pOut.day);
            // La habitación está ocupada hoy si checkIn <= today < checkOut
            if (!today.isBefore(startDay) && today.isBefore(endDay)) {
              isOccupiedToday = true;
              if (activeCheckOutDate == null || pOut.isAfter(activeCheckOutDate!)) {
                activeCheckOutDate = pOut;
              }
            }
          }
        }
      }
    }

    final reservasRaw = json['reservas'];
    if (reservasRaw is List) {
      for (final r in reservasRaw) {
        processBooking(r);
      }
    } else if (reservasRaw is Map) {
      processBooking(reservasRaw);
    }

    bookedRanges.sort((a, b) => a.checkIn.compareTo(b.checkIn));

    String dbStatus = (json['estado'] ?? 'Disponible').toString().trim();
    String calculatedStatus = dbStatus;

    if (dbStatus.toLowerCase() == 'ocupada' || isOccupiedToday) {
      calculatedStatus = 'Ocupada';
      if (activeCheckOutDate == null) {
        activeCheckOutDate = DateTime.now().add(const Duration(days: 3));
      }
    } else if (dbStatus.toLowerCase() == 'disponible') {
      calculatedStatus = 'Disponible';
    }

    return RoomModel(
      id: json['id'],
      numero: json['numero']?.toString() ?? 'S/N',
      tipoId: tipoId,
      tipoNombre: tipo['nombre']?.toString() ?? 'Habitación',
      tipoDescripcion: tipo['descripcion']?.toString() ?? '',
      capacidad: (tipo['capacidad_personas'] as num?)?.toInt() ?? 1,
      precioBase: ((caracMap['precio_personalizado'] ?? tipo['precio_base_noche']) as num?)?.toDouble() ?? 150000.0,
      piso: (json['piso'] as num?)?.toInt() ?? 1,
      estado: calculatedStatus,
      caracteristicas: caracMap.isNotEmpty
          ? caracMap
          : {'wifi': true, 'ac': true, 'tv': true, 'minibar': true},
      observaciones: json['observaciones']?.toString(),
      imagenCover: cover,
      imagenes: imageGallery,
      fechaDisponibleDesde: activeCheckOutDate,
      bookedRanges: bookedRanges,
    );
  }
}
