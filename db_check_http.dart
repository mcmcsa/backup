import 'dart:io';
import 'dart:convert';

void main() async {
  print('Sending HTTP request to Supabase Rest API...');
  final url = Uri.parse('https://koszfvvodjctiytbflup.supabase.co/rest/v1/work_requests?select=*,requestor:users!work_requests_requestor_id_fkey(name)&limit=5&order=date_submitted.desc');
  
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.headers.set('apikey', 'sb_publishable_39jKzuDntPex2oZgplFxqg_JKLbKkDB');
    request.headers.set('Authorization', 'Bearer sb_publishable_39jKzuDntPex2oZgplFxqg_JKLbKkDB');
    
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode != 200) {
      print('HTTP Error: ${response.statusCode}');
      print(responseBody);
      return;
    }
    
    final data = json.decode(responseBody) as List;
    print('Fetched ${data.length} records.');
    for (var i = 0; i < data.length; i++) {
      final record = data[i];
      print('--- Record $i ---');
      print('id: ${record['id']}');
      print('requestor_id: ${record['requestor_id']}');
      print('requestor_name: ${record['requestor_name']}');
      print('reported_by_name: ${record['reported_by_name']}');
      print('requestor relation: ${record['requestor']}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
