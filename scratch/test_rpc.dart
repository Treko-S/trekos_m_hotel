import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://nfbiqdhiowroosvfazid.supabase.co';
  final serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg';
  final client = HttpClient();

  final rpcs = ['exec_sql', 'execute_sql', 'exec', 'run_sql', 'query'];
  for (var rpc in rpcs) {
    try {
      final req = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/rpc/$rpc'));
      req.headers.set('apikey', serviceKey);
      req.headers.set('Authorization', 'Bearer $serviceKey');
      req.headers.set('Content-Type', 'application/json');
      req.write(jsonEncode({'query': 'SELECT 1;'}));
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      print('RPC $rpc: ${res.statusCode} - $body');
    } catch (e) {
      print('RPC $rpc error: $e');
    }
  }
}
