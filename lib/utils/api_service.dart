import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static Future<http.Response> get(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<http.Response> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    return await http.post(
      Uri.parse(url),
      body: jsonEncode(body),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }
}
