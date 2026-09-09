import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = "https://nfbiqdhiowroosvfazid.supabase.co";
  final serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg";

  final client = HttpClient();
  
  // Try inserting and deleting a dummy test row to see allowed columns
  final req = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/acompanantes'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  req.headers.set('Content-Type', 'application/json');
  req.headers.set('Prefer', 'return=representation');
  req.write(jsonEncode({
    'reserva_id': 1,
    'full_name': 'Test Acompanante',
    'document_number': '1234567'
  }));
  final res = await req.close();
  final body = await utf8.decodeStream(res);
  print('Insert status ${res.statusCode}: $body');

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final list = jsonDecode(body) as List;
    if (list.isNotEmpty) {
      final id = list[0]['id'];
      // delete
      final delReq = await client.deleteUrl(Uri.parse('$supabaseUrl/rest/v1/acompanantes?id=eq.$id'));
      delReq.headers.set('apikey', serviceKey);
      delReq.headers.set('Authorization', 'Bearer $serviceKey');
      final delRes = await delReq.close();
      print('Delete status: ${delRes.statusCode}');
    }
  }
}
