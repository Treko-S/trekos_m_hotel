import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = "https://nfbiqdhiowroosvfazid.supabase.co";
  final serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg";

  final client = HttpClient();
  final req = await client.getUrl(Uri.parse('$supabaseUrl/rest/v1/reservas?select=*&limit=1'));
  req.headers.set('apikey', serviceKey);
  req.headers.set('Authorization', 'Bearer $serviceKey');
  final res = await req.close();
  final body = await utf8.decodeStream(res);
  print(body);
}
