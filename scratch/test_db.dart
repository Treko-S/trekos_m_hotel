import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = "https://nfbiqdhiowroosvfazid.supabase.co";
  final serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg";

  final client = HttpClient();
  
  final tables = [
    'habitaciones', 
    'tipos_habitacion', 
    'reservas', 
    'folios', 
    'acompanantes', 
    'users', 
    'temporadas', 
    'productos_servicios', 
    'ordenes_mantenimiento', 
    'ordenes_compra', 
    'proveedores', 
    'sesiones_caja'
  ];

  for (final table in tables) {
    try {
      final req = await client.getUrl(Uri.parse('$supabaseUrl/rest/v1/$table?select=*&limit=5'));
      req.headers.set('apikey', serviceKey);
      req.headers.set('Authorization', 'Bearer $serviceKey');
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = jsonDecode(body) as List;
        print('Table $table: ${list.length} rows (status ${res.statusCode})');
      } else {
        print('Table $table: HTTP ${res.statusCode} - $body');
      }
    } catch (e) {
      print('Table $table error: $e');
    }
  }
}
