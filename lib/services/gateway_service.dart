import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gateway_status.dart';

class GatewayService {
  String baseUrl;
  String? token;

  GatewayService({this.baseUrl = 'http://localhost:18789', this.token});

  Future<GatewayStatus?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/mobile/status'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return GatewayStatus.fromJson(json);
      }
    } catch (e) {
      print('Error getting status: $e');
    }
    return null;
  }

  Future<bool> testConnection() async {
    try {
      final status = await getStatus();
      return status != null;
    } catch (e) {
      return false;
    }
  }
}
