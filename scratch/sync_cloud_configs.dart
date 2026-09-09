import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://nfbiqdhiowroosvfazid.supabase.co';
  final serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg';
  final client = HttpClient();

  // 1. hotel_settings data
  final settingsData = {
    'id': 1,
    'hotel_name': 'Hotel 3 Vagos',
    'commercial_name': 'Hospitality UTCD',
    'ruc': '80092341-2',
    'address': 'Avda. Santa Teresa c/ Aviadores del Chaco, Asunción, Paraguay',
    'phone': '+595 21 600 000',
    'whatsapp': '+595 981 123 456',
    'email': 'reservas@hotel3vagos.com.py',
    'currency': 'Gs.',
    'timezone': 'America/Asuncion',
    'check_in_time': '14:00',
    'check_out_time': '11:00',
    'cancellation_policy_text': 'Cancelación 100% gratuita hasta 24 hs previas al check-in en Tarifa Flexible. Tarifa Promo No Reembolsable no admite devolución.',
    'terms_and_conditions_text': 'Prohibido fumar en las habitaciones. Check-in a partir de las 14:00 hs. Presentar documento legal oficial de identidad.',
    'logo_url': 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
    'iva_percent': 10
  };

  // 2. promotional_packages initial data
  final packagesData = [
    {
      'id': 'pkg-romantico-01',
      'name': 'Paquete Escapada Romántica & Spa',
      'description': 'Estadía inolvidable en pareja con espumante, chocolates finos, sesión de spa para 2 personas y late check-out.',
      'room_type_id': 2, // Habitación Doble / Matrimonial
      'room_type_name': 'Habitacion Doble Superior',
      'package_price': 580000,
      'image_url': 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800',
      'is_active': true,
      'included_services': [
        {'id': 1, 'name': 'Desayuno Buffet Americano en Habitación', 'qty': 2, 'price': 0},
        {'id': 2, 'name': 'Masaje Relajante Descontracturante (50 min)', 'qty': 2, 'price': 0},
        {'id': 4, 'name': 'Cerveza Corona Extra / Espumante de Bienvenida', 'qty': 2, 'price': 0}
      ]
    },
    {
      'id': 'pkg-relax-02',
      'name': 'Paquete Fin de Semana Relax Total',
      'description': 'Desconexión completa con acceso a sauna, circuito termal, almuerzo buffet y frigobar libre.',
      'room_type_id': 3, // Suite Matrimonial
      'room_type_name': 'Suite Matrimonial de Lujo',
      'package_price': 750000,
      'image_url': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800',
      'is_active': true,
      'included_services': [
        {'id': 2, 'name': 'Circuito Spa & Sauna Relax', 'qty': 2, 'price': 0},
        {'id': 5, 'name': 'Almuerzo Gourmet Restó 3 Vagos', 'qty': 2, 'price': 0},
        {'id': 3, 'name': 'Agua Mineral y Snacks de Frigobar', 'qty': 4, 'price': 0}
      ]
    }
  ];

  // Upload to Supabase Storage bucket 'hotel-rooms'
  Future<void> uploadStorage(String path, String content) async {
    try {
      final req = await client.postUrl(Uri.parse('$supabaseUrl/storage/v1/object/hotel-rooms/$path'));
      req.headers.set('apikey', serviceKey);
      req.headers.set('Authorization', 'Bearer $serviceKey');
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('x-upsert', 'true');
      req.write(content);
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      print('Uploaded $path: ${res.statusCode} - $body');
    } catch (e) {
      print('Error uploading $path: $e');
    }
  }

  await uploadStorage('config/hotel_settings.json', jsonEncode(settingsData));
  await uploadStorage('config/promotional_packages.json', jsonEncode(packagesData));

  // Try upserting to Supabase table if table exists
  try {
    final req = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/hotel_settings'));
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'resolution=merge-duplicates');
    req.write(jsonEncode(settingsData));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    print('DB hotel_settings: ${res.statusCode} - $body');
  } catch (e) {
    print('DB hotel_settings err: $e');
  }

  print('Sync cloud configs completed.');
}
