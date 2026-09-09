import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = "https://nfbiqdhiowroosvfazid.supabase.co";
  final serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg";

  final client = HttpClient();

  // 1. Reset all rooms to 'Disponible'
  final req = await client.patchUrl(Uri.parse('$supabaseUrl/rest/v1/habitaciones?id=gt.0'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Prefer', 'return=representation');
  req.write(jsonEncode({'estado': 'Disponible', 'observaciones': null}));
  final res = await req.close();
  print('Reset Habitaciones: ${res.statusCode}');

  // 2. Clean acompanantes
  final compReq = await client.deleteUrl(Uri.parse('$supabaseUrl/rest/v1/acompanantes?id=gt.0'));
  compReq.headers.set('apikey', serviceKey);
  compReq.headers.set('Authorization', 'Bearer $serviceKey');
  final compRes = await compReq.close();
  print('Clean Acompanantes: ${compRes.statusCode}');

  // 3. Clean ordenes_mantenimiento
  final ordReq = await client.deleteUrl(Uri.parse('$supabaseUrl/rest/v1/ordenes_mantenimiento?id=gt.0'));
  ordReq.headers.set('apikey', serviceKey);
  ordReq.headers.set('Authorization', 'Bearer $serviceKey');
  final ordRes = await ordReq.close();
  print('Clean Ordenes Mantenimiento: ${ordRes.statusCode}');

  print('Tarea 0 Cleanup completed successfully.');
}
