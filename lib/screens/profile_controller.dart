import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';

class ProfileState {
  final bool isLoading;
  final File? pickedImage;
  final String? profileUrl;
  final String name;
  final String email;
  final String role;
  final String phoneNumber;
  final String rollNumber;
  final String courseName;
  final String currentSemester;

  ProfileState({
    this.isLoading = false,
    this.pickedImage,
    this.profileUrl,
    this.name = '',
    this.email = '',
    this.role = 'student',
    this.phoneNumber = '',
    this.rollNumber = '',
    this.courseName = '',
    this.currentSemester = '',
  });

  ProfileState copyWith({
    bool? isLoading,
    File? pickedImage,
    String? profileUrl,
    String? name,
    String? email,
    String? role,
    String? phoneNumber,
    String? rollNumber,
    String? courseName,
    String? currentSemester,
    bool clearPickedImage = false,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      pickedImage: clearPickedImage ? null : (pickedImage ?? this.pickedImage),
      profileUrl: profileUrl ?? this.profileUrl,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      rollNumber: rollNumber ?? this.rollNumber,
      courseName: courseName ?? this.courseName,
      currentSemester: currentSemester ?? this.currentSemester,
    );
  }
}

final userProfileProvider = FutureProvider.autoDispose<ProfileState>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  if (token == null || token.isEmpty) return ProfileState(role: 'guest');

  try {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/me"),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['user'];
      return ProfileState(
        name: data['name'] ?? '',
        email: data['email'] ?? '',
        profileUrl: data['profile_pic'],
        role: data['role'].toString().toLowerCase().trim(),
        phoneNumber: data['phone_number'] ?? 'N/A',
        rollNumber: data['roll_number'] ?? 'N/A',
        courseName: data['course_name']?.toString() ?? 'No Course',
        currentSemester: data['current_semester']?.toString() ?? '0',
      );
    }
    throw Exception("Error");
  } catch (e) {
    rethrow;
  }
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
      final asyncData = ref.watch(userProfileProvider);
      return ProfileController(ref, asyncData.value ?? ProfileState());
    });

class ProfileController extends StateNotifier<ProfileState> {
  final Ref _ref;
  ProfileController(this._ref, super.initialState);

  final _picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) {
      state = state.copyWith(pickedImage: File(image.path));
    }
  }

  Future<void> saveProfile({
    required String newName,
    required String newEmail,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${ApiConfig.baseUrl}/update-profile"),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      request.fields['name'] = newName;
      request.fields['email'] = newEmail;

      if (state.pickedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_pic',
            state.pickedImage!.path,
          ),
        );
      }

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final String newUrl = data['user']['profile_pic'];

        state = state.copyWith(
          isLoading: false,
          name: newName,
          email: newEmail,
          profileUrl: "$newUrl?v=${DateTime.now().millisecondsSinceEpoch}",
          clearPickedImage: true,
        );

        _ref.invalidate(userProfileProvider);
        if (onSuccess != null) onSuccess();
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      if (onError != null) onError(e.toString());
    }
  }
}
