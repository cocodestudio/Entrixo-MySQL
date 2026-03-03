import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/forgot_password_screen.dart';
import '../utils/api_config.dart';
import '../utils/custom_toast.dart';
import '../widgets/geometric_loader.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _oldFocus = FocusNode();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _isOldVisible = false;
  bool _isNewVisible = false;
  bool _isConfirmVisible = false;

  @override
  void initState() {
    super.initState();
    _oldFocus.addListener(() => setState(() {}));
    _newFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  bool _isStrongPassword(String password) {
    return RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$',
    ).hasMatch(password);
  }

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      CustomToast.show(context, "Please fill all fields", isError: true);
      return;
    }

    if (!_isStrongPassword(newPassword)) {
      CustomToast.show(
        context,
        "Password must be at least 8 chars with 1 letter and 1 number",
        isError: true,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      CustomToast.show(context, "New passwords do not match", isError: true);
      return;
    }

    if (oldPassword == newPassword) {
      CustomToast.show(
        context,
        "New password must be different from old password",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();

      final response = await http.post(
        Uri.parse(ApiConfig.changePassword),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          CustomToast.show(context, "Password Changed Successfully!");
          Navigator.pop(context);
        }
      } else {
        String errorMessage = data['message'] ?? "Failed to change password";
        if (data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first[0];
        }
        if (mounted) CustomToast.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          "Server Error. Please check your connection.",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Security Settings",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "Change Password",
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Update your password regularly to keep your account secure.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildLabel("Current Password"),
                      _buildPasswordField(
                        controller: _oldPasswordController,
                        focusNode: _oldFocus,
                        hint: "Enter your old password",
                        isVisible: _isOldVisible,
                        onVisibilityToggle: () =>
                            setState(() => _isOldVisible = !_isOldVisible),
                        theme: theme,
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          style:
                              TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                splashFactory: NoSplash.splashFactory,
                                foregroundColor: theme.primaryColor,
                              ).copyWith(
                                overlayColor: WidgetStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                          child: Text(
                            'Forgot Password?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _buildLabel("New Password"),
                      _buildPasswordField(
                        controller: _newPasswordController,
                        focusNode: _newFocus,
                        hint: "Minimum 8 characters",
                        isVisible: _isNewVisible,
                        onVisibilityToggle: () =>
                            setState(() => _isNewVisible = !_isNewVisible),
                        theme: theme,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("Confirm New Password"),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        focusNode: _confirmFocus,
                        hint: "Re-enter new password",
                        isVisible: _isConfirmVisible,
                        onVisibilityToggle: () => setState(
                          () => _isConfirmVisible = !_isConfirmVisible,
                        ),
                        theme: theme,
                      ),

                      const SizedBox(height: 32),

                      // Password Policy Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 18,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "PASSWORD POLICY",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: theme.primaryColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildBulletPoint(
                              "Must be at least 8 characters long.",
                            ),
                            const SizedBox(height: 8),
                            _buildBulletPoint(
                              "Must contain at least one letter and one number.",
                            ),
                            const SizedBox(height: 8),
                            _buildBulletPoint(
                              "Must be different from your current password.",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Bottom Button Section (Consistent with Add Faculty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  border: Border(
                    top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      disabledBackgroundColor: theme.colorScheme.secondary
                          .withOpacity(0.6),
                      elevation: _isLoading ? 0 : 2,
                      shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const GeometricLoader(size: 28, isDarkMode: false)
                        : Text(
                            "Update Password",
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4A4A4A),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
    required ThemeData theme,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: focusNode.hasFocus
            ? Colors.white
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: focusNode.hasFocus
              ? theme.primaryColor.withOpacity(0.8)
              : const Color(0xFFE5E7EB),
          width: focusNode.hasFocus ? 1.8 : 1.2,
        ),
        boxShadow: focusNode.hasFocus
            ? [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color: focusNode.hasFocus
                ? theme.primaryColor
                : const Color(0xFF888888),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: !isVisible,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                fontSize: 15,
                color: const Color(0xFF1A1A1A),
              ),
              cursorColor: theme.primaryColor,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFAAAAAA),
                  letterSpacing: 0.5,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: onVisibilityToggle,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(left: 10),
              child: Icon(
                isVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: const Color(0xFFAAAAAA),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: CircleAvatar(radius: 3, backgroundColor: Colors.grey[400]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
