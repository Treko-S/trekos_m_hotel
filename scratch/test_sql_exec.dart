import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = "https://nfbiqdhiowroosvfazid.supabase.co";
  final serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg";

  final client = HttpClient();

  // Test pg/query endpoint
  try {
    final req = await client.postUrl(Uri.parse('$supabaseUrl/pg/query'));
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode({"query": "SELECT 1 as connected;"}));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    print('/pg/query: HTTP ${res.statusCode} - $body');
  } catch (e) {
    print('/pg/query error: $e');
  }

  // Test sql rpc endpoint
  try {
    final req = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/rpc/execute_sql'));
    req.headers.set('apikey', serviceKey);
    req.headers.set('Authorization', 'Bearer $serviceKey');
    req.headers.set('Content-Type', 'application/json');
    req.write(jsonEncode({"query": "SELECT 1;"}));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    print('/rest/v1/rpc/execute_sql: HTTP ${res.statusCode} - $body');
  } catch (e) {
    print('rpc error: $e');
  }
}
