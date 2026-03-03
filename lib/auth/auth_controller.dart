import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../screens/profile_controller.dart';
import '../utils/custom_toast.dart';
import 'auth_repository.dart';
import 'login_screen.dart';

final authControllerProvider = StateNotifierProvider<AuthController, bool>((
    ref,
    ) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    ref: ref,
  );
});

class AuthController extends StateNotifier<bool> {
  final AuthRepository authRepository;
  final Ref ref;

  AuthController({required this.authRepository, required this.ref})
      : super(false);

  Future<void> login(
      BuildContext context,
      String loginId,
      String password,
      Function(String role) onSuccess,
      ) async {
    state = true;
    try {
      final responseData = await authRepository.loginWithEmailPassword(
        loginId,
        password,
      );

      final user = responseData['user'];
      final String role = (user['role'] ?? 'student')
          .toString()
          .toLowerCase()
          .trim();

      ref.invalidate(userProfileProvider);

      state = false;
      onSuccess(role);
    } catch (e) {
      state = false;
      if (context.mounted) {
        CustomToast.show(
          context,
          e.toString().replaceAll("Exception: ", ""),
          isError: true,
        );
      }
    }
  }

  Future<void> logout(BuildContext context, WidgetRef ref) async {
    state = true;
    try {
      await authRepository.logout();
    } catch (e) {
      debugPrint("Logout cleanup error: $e");
    } finally {
      state = false;
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }
}