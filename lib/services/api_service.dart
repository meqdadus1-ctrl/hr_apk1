import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── تحويل الـ response bytes إلى Map (مشترك)
  static Map<String, dynamic> decodeResponse(Uint8List bytes) {
    return jsonDecode(utf8.decode(bytes));
  }

  // ── GET
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final headers = await getHeaders();
    final response = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}$endpoint'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 30));
    return decodeResponse(response.bodyBytes);
  }

  // ── POST
  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    final response = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return decodeResponse(response.bodyBytes);
  }

  // ── PUT
  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> body) async {
    final headers = await getHeaders();
    final response = await http
        .put(
          Uri.parse('${AppConstants.baseUrl}$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));
    return decodeResponse(response.bodyBytes);
  }
}
