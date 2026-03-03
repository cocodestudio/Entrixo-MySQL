import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import '../utils/custom_toast.dart';
import '../widgets/geometric_loader.dart';

class AddAdminScreen extends StatefulWidget {
  const AddAdminScreen({super.key});

  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _createAdmin() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      CustomToast.show(
        context,
        "Please fill all required fields",
        isError: true,
      );
      return;
    }

    if (!RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(email)) {
      CustomToast.show(context, "Please enter a valid email", isError: true);
      return;
    }

    if (phone.length < 10) {
      CustomToast.show(
        context,
        "Please enter a valid 10-digit phone number",
        isError: true,
      );
      return;
    }

    if (password.length < 6) {
      CustomToast.show(
        context,
        "Password must be at least 6 characters",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();

      final response = await http.post(
        Uri.parse(
          ApiConfig.registerAdmin,
        ), // Ensure this is defined in your ApiConfig
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone_number': phone,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          CustomToast.show(context, "Admin Registered Successfully!");
          Navigator.pop(context);
        }
      } else {
        String errorMessage = data['message'] ?? "Registration failed";
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

  void _showRevokeAccessSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RevokeAdminBottomSheet(),
    );
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
            "Manage Faculty",
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
                        "Create New Faculty",
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Register a new faculty member with administrative privileges.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildLabel("Full Name"),
                      _buildTextField(
                        controller: _nameController,
                        focusNode: _nameFocus,
                        icon: Icons.person_outline_rounded,
                        hint: "e.g. Dr. Rajesh Kumar",
                        theme: theme,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("Email Address"),
                      _buildTextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        icon: Icons.email_outlined,
                        hint: "faculty@college.edu",
                        theme: theme,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("Mobile Number"),
                      _buildTextField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        icon: Icons.phone_outlined,
                        hint: "Enter 10-digit number",
                        theme: theme,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel("Create Password"),
                      _buildPasswordField(theme),

                      const SizedBox(height: 32),

                      // Security Protocol Card
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
                                  Icons.security_rounded,
                                  size: 18,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "SECURITY PROTOCOL",
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
                              "This action grants full administrative access.",
                            ),
                            const SizedBox(height: 8),
                            _buildBulletPoint(
                              "Credentials will be securely hashed in database.",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE5E7EB),
                      ),
                      const SizedBox(height: 32),

                      // Danger Zone (Revoke Access)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5).withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "DANGER ZONE",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFDC2626),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Need to remove an existing admin? Revoking access will immediately delete their administrative account.",
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF991B1B),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: OutlinedButton(
                                onPressed: _showRevokeAccessSheet,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(
                                    color: Color(0xFFF87171),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Revoke Access",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Register Button at bottom
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
                    onPressed: _isLoading ? null : _createAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      disabledBackgroundColor: theme.colorScheme.secondary
                          .withOpacity(0.6),
                      elevation: _isLoading ? 0 : 4,
                      shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const GeometricLoader(size: 28, isDarkMode: false)
                        : Text(
                            "Grant Admin Access",
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

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    required ThemeData theme,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
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
            icon,
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
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              inputFormatters: maxLength != null
                  ? [
                      LengthLimitingTextInputFormatter(maxLength),
                      if (keyboardType == TextInputType.phone)
                        FilteringTextInputFormatter.digitsOnly,
                    ]
                  : null,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: const Color(0xFF1A1A1A),
              ),
              cursorColor: theme.primaryColor,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFAAAAAA),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _passwordFocus.hasFocus
            ? Colors.white
            : Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _passwordFocus.hasFocus
              ? theme.primaryColor.withOpacity(0.8)
              : const Color(0xFFE5E7EB),
          width: _passwordFocus.hasFocus ? 1.8 : 1.2,
        ),
        boxShadow: _passwordFocus.hasFocus
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
            color: _passwordFocus.hasFocus
                ? theme.primaryColor
                : const Color(0xFF888888),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              obscureText: !_isPasswordVisible,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                fontSize: 15,
                color: const Color(0xFF1A1A1A),
              ),
              cursorColor: theme.primaryColor,
              decoration: InputDecoration(
                hintText: "Minimum 6 characters",
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
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                setState(() => _isPasswordVisible = !_isPasswordVisible),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(left: 10),
              child: Icon(
                _isPasswordVisible
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

class RevokeAdminBottomSheet extends StatefulWidget {
  const RevokeAdminBottomSheet({super.key});

  @override
  State<RevokeAdminBottomSheet> createState() => _RevokeAdminBottomSheetState();
}

class _RevokeAdminBottomSheetState extends State<RevokeAdminBottomSheet> {
  final TextEditingController _identifierController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isDeleting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _revokeAccess() async {
    FocusScope.of(context).unfocus();
    final identifier = _identifierController.text.trim();

    if (identifier.isEmpty) {
      CustomToast.show(
        context,
        "Please enter email or phone number",
        isError: true,
      );
      return;
    }

    setState(() => _isDeleting = true);

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.revokeAdmin),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'identifier': identifier}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          CustomToast.show(context, data['message'] ?? "Admin Revoked!");
          Navigator.pop(context); // Close bottom sheet
        }
      } else {
        if (mounted) {
          CustomToast.show(
            context,
            data['message'] ?? "Failed to revoke admin",
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Server Error", isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Revoke Faculty Access",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the registered Email or Phone number of the admin you want to remove permanently.",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            height: 58,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF888888),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextField(
                    controller: _identifierController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      hintText: "Email or Phone",
                      hintStyle: TextStyle(
                        color: Color(0xFFAAAAAA),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isDeleting ? null : _revokeAccess,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                disabledBackgroundColor: const Color(
                  0xFFDC2626,
                ).withOpacity(0.6),
                elevation: _isDeleting ? 0 : 4,
                shadowColor: const Color(0xFFDC2626).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Revoke Now",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
