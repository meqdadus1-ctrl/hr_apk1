import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../utils/constants.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await ApiService.post('/login', {
      'email': email,
      'password': password,
      'fcm_token': 'flutter_token',
    });

    if (response['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, response['token']);
      await prefs.setString(
          AppConstants.employeeKey, jsonEncode(response['employee']));
    }

    return response;
  }

  static Future<void> logout() async {
    await ApiService.post('/logout', {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.employeeKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey) != null;
  }

  static Future<Map<String, dynamic>?> getEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(AppConstants.employeeKey);
    if (data == null) return null;
    return jsonDecode(data);
  }
}