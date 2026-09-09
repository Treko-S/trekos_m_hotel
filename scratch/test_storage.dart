import 'dart:convert';
import 'dart:io';

void main() async {
  final supabaseUrl = "https://nfbiqdhiowroosvfazid.supabase.co";
  final serviceKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5mYmlxZGhpb3dyb29zdmZhemlkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODA4MTExMCwiZXhwIjoyMTAzNjU3MTEwfQ.cvmJ_LOTvTX4VSyNlRVqtPB-K_EhMBQunB3oQh4c1bg";

  final client = HttpClient();
  
  // Test writing to storage
  final uploadReq = await client.postUrl(Uri.parse('$supabaseUrl/storage/v1/object/hotel-rooms/config/test.json'));
  uploadReq.headers.set('apikey', serviceKey);
  uploadReq.headers.set('Authorization', 'Bearer $serviceKey');
  uploadReq.headers.set('Content-Type', 'application/json');
  uploadReq.headers.set('x-upsert', 'true');
  uploadReq.write(jsonEncode({'test': true, 'timestamp': DateTime.now().toIso8601String()}));
  final uploadRes = await uploadReq.close();
  final uploadBody = await utf8.decodeStream(uploadRes);
  print('Upload: ${uploadRes.statusCode} - $uploadBody');

  // Test reading back
  final getReq = await client.getUrl(Uri.parse('$supabaseUrl/storage/v1/object/public/hotel-rooms/config/test.json'));
  final getRes = await getReq.close();
  final getBody = await utf8.decodeStream(getRes);
  print('Read: ${getRes.statusCode} - $getBody');
}
