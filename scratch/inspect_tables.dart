import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://nfbiqdhiowroosvfazid.supabase.co';
  final serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg';
  final client = HttpClient();
  final tables = [
    'sesiones_caja',
    'tipos_habitacion',
    'reservas',
    'hotel_settings',
    'promotional_packages',
    'package_included_services',
    'tax_rules',
    'room_types',
    'facturas',
    'comprobantes'
  ];
  for (var table in tables) {
    try {
      final req = await client.getUrl(Uri.parse('$supabaseUrl/rest/v1/$table?select=*&limit=1'));
      req.headers.set('apikey', serviceKey);
      req.headers.set('Authorization', 'Bearer $serviceKey');
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      print('$table [${res.statusCode}]: ${body.length > 200 ? body.substring(0, 200) : body}');
    } catch (e) {
      print('$table error: $e');
    }
  }
}
