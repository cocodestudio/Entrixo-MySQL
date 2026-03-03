import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../utils/api_config.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthRepository {
  Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown_ios_device";
    }
  }

  Future<Map<String, dynamic>> loginWithEmailPassword(
    String loginId,
    String password,
  ) async {
    final deviceId = await getDeviceId();

    final response = await http.post(
      Uri.parse(ApiConfig.login),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'login_id': loginId,
        'password': password,
        'device_name': deviceId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['token']);
      await prefs.setString('user_role', data['user']['role']);

      return data;
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? "Login Failed");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token != null) {
      try {
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (e) {}
    }

    await prefs.clear();
  }
}
