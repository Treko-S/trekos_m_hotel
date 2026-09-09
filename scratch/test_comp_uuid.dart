import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = "https://nfbiqdhiowroosvfazid.supabase.co";
  final serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg";

  final client = HttpClient();
  
  // Try inserting with known reservation UUID
  const resId = "fe1754f4-c93d-4519-ac83-e3443c42ad3a";
  final req = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/acompanantes'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Prefer', 'return=representation');
  req.write(jsonEncode({
    'reserva_id': resId,
    'full_name': 'Acompanante Test',
    'document_number': '5432100'
  }));
  final res = await req.close();
  final body = await utf8.decodeStream(res);
  print('Insert status ${res.statusCode}: $body');

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final list = jsonDecode(body) as List;
    final id = list[0]['id'];
    print('Inserted row: ${list[0]}');
    final delReq = await client.deleteUrl(Uri.parse('$supabaseUrl/rest/v1/acompanantes?id=eq.$id'));
    delReq.headers.set('apikey', serviceKey);
    delReq.headers.set('Authorization', 'Bearer $serviceKey');
    await delReq.close();
    print('Deleted test row');
  }
}
