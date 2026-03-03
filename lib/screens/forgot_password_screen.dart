import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../utils/custom_toast.dart';
import '../widgets/geometric_loader.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _otpFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _emailFocus.addListener(() => setState(() {}));
    _otpFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmPasswordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _otpFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();

    if (email.isEmpty ||
        !RegExp(
          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
        ).hasMatch(email)) {
      CustomToast.show(
        context,
        "Enter a valid registered email",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendOtp),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        CustomToast.show(context, data['message'] ?? "OTP sent to your email!");
        setState(() => _currentStep = 1);
      } else {
        CustomToast.show(
          context,
          data['message'] ?? "Failed to send OTP",
          isError: true,
        );
      }
    } catch (e) {
      CustomToast.show(
        context,
        "Network Error. Please try again.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      CustomToast.show(context, "Enter a valid 6-digit OTP", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyOtp),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': _emailController.text.trim(), 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        CustomToast.show(context, "OTP Verified!");
        setState(() => _currentStep = 2);
      } else {
        CustomToast.show(
          context,
          data['message'] ?? "Invalid OTP",
          isError: true,
        );
      }
    } catch (e) {
      CustomToast.show(
        context,
        "Network Error. Please try again.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.length < 6) {
      CustomToast.show(
        context,
        "Password must be at least 6 characters",
        isError: true,
      );
      return;
    }
    if (password != confirmPassword) {
      CustomToast.show(context, "Passwords do not match", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.resetPassword),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'otp': _otpController.text.trim(),
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        CustomToast.show(context, "Password reset successfully! Please login.");
        Navigator.pop(context);
      } else {
        CustomToast.show(
          context,
          data['message'] ?? "Failed to reset password",
          isError: true,
        );
      }
    } catch (e) {
      CustomToast.show(
        context,
        "Network Error. Please try again.",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * (isKeyboardVisible ? 0.25 : 0.45),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ForgotPasswordIllustrationPainter(
                      progress: _animationController.value,
                      primaryColor: theme.primaryColor,
                      accentColor: theme.colorScheme.secondary,
                      currentStep: _currentStep,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black87,
                ),
                onPressed: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep--);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            Positioned(
              top: size.height * (isKeyboardVisible ? 0.22 : 0.4),
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.08),
                      blurRadius: 30,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.05, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: _buildCurrentStep(theme),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep(ThemeData theme) {
    if (_currentStep == 0) return _buildEmailStep(theme);
    if (_currentStep == 1) return _buildOtpStep(theme);
    return _buildPasswordStep(theme);
  }

  Widget _buildEmailStep(ThemeData theme) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Forgot Password',
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your registered email address to receive a 6-digit secure OTP.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF666666),
            height: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 40),
        _buildTextField(
          controller: _emailController,
          focusNode: _emailFocus,
          icon: Icons.email_outlined,
          hint: 'Email Address',
          keyboardType: TextInputType.emailAddress,
          theme: theme,
        ),
        const SizedBox(height: 40),
        _buildActionButton(
          label: 'Send OTP',
          onPressed: _sendOtp,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildOtpStep(ThemeData theme) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify Identity',
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit security code sent to\n${_emailController.text}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF666666),
            height: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 40),
        _buildTextField(
          controller: _otpController,
          focusNode: _otpFocus,
          icon: Icons.pin_outlined,
          hint: '000000',
          keyboardType: TextInputType.number,
          maxLength: 6,
          isCenter: true,
          letterSpacing: 16.0,
          theme: theme,
        ),
        const SizedBox(height: 40),
        _buildActionButton(
          label: 'Verify Code',
          onPressed: _verifyOtp,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildPasswordStep(ThemeData theme) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create New Password',
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your new password must be unique and secure. Do not share it.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF666666),
            height: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 40),
        _buildPasswordField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          hint: 'New Password',
          isVisible: _isPasswordVisible,
          onVisibilityToggle: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
          theme: theme,
        ),
        const SizedBox(height: 24),
        _buildPasswordField(
          controller: _confirmPasswordController,
          focusNode: _confirmPasswordFocus,
          hint: 'Confirm Password',
          isVisible: _isConfirmPasswordVisible,
          onVisibilityToggle: () => setState(
            () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
          ),
          theme: theme,
        ),
        const SizedBox(height: 40),
        _buildActionButton(
          label: 'Reset & Login',
          onPressed: _resetPassword,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    required ThemeData theme,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool isCenter = false,
    double letterSpacing = 0.5,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: 58,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: focusNode.hasFocus ? Colors.white : const Color(0xFFF7F8FA),
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
                  color: theme.primaryColor.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isCenter) ...[
            Icon(
              icon,
              size: 20,
              color: focusNode.hasFocus
                  ? theme.primaryColor
                  : const Color(0xFF888888),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textAlign: isCenter ? TextAlign.center : TextAlign.left,
              inputFormatters: maxLength != null
                  ? [LengthLimitingTextInputFormatter(maxLength)]
                  : null,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: letterSpacing,
                fontSize: isCenter ? 22 : 15,
                color: const Color(0xFF1A1A1A),
              ),
              cursorColor: theme.primaryColor,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFAAAAAA),
                  letterSpacing: isCenter
                      ? (controller.text.isEmpty ? 1.0 : 12.0)
                      : 0.5,
                  fontSize: isCenter ? 20 : 14,
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
        ],
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
        color: focusNode.hasFocus ? Colors.white : const Color(0xFFF7F8FA),
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
                  color: theme.primaryColor.withOpacity(0.1),
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
                // --- Clean UI Fix ---
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

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          disabledBackgroundColor: theme.colorScheme.secondary.withOpacity(0.6),
          elevation: _isLoading ? 0 : 2,
          shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const GeometricLoader(size: 28, isDarkMode: false)
            : Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class ForgotPasswordIllustrationPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color accentColor;
  final int currentStep;

  ForgotPasswordIllustrationPainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
    required this.currentStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2.2);
    final maxRadius = math.min(size.width, size.height) * 0.35;

    // Background Glow
    final bgGradient = RadialGradient(
      colors: [
        accentColor.withOpacity(0.15),
        primaryColor.withOpacity(0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawCircle(
      center,
      maxRadius * 2.2,
      Paint()
        ..shader = bgGradient.createShader(
          Rect.fromCircle(center: center, radius: maxRadius * 2.2),
        ),
    );

    // Dynamic Orbits based on current step
    final orbitSpeed = currentStep == 1 ? 4 : 2;

    for (int i = 1; i <= 3; i++) {
      final radius = maxRadius * (i / 3.5);
      final pulse = math.sin(progress * math.pi * orbitSpeed + i * 0.5) * 4;
      final opacity = 0.03 + (i * 0.02);

      canvas.drawCircle(
        center,
        radius + pulse,
        Paint()
          ..color = primaryColor.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Central Icon logic based on Step
    if (currentStep == 0) {
      _drawMailIcon(canvas, center, maxRadius * 0.4);
    } else if (currentStep == 1) {
      _drawShieldIcon(canvas, center, maxRadius * 0.45);
    } else {
      _drawKeyIcon(canvas, center, maxRadius * 0.4);
    }

    // Floating Particles
    _drawParticles(canvas, center, maxRadius, progress);
  }

  void _drawMailIcon(Canvas canvas, Offset center, double size) {
    final rect = Rect.fromCenter(
      center: center,
      width: size * 2,
      height: size * 1.4,
    );
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      paint,
    );

    final path = Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(center.dx, center.dy + size * 0.2)
      ..lineTo(rect.right, rect.top);

    canvas.drawPath(path, paint);

    // Pulse glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..color = accentColor.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _drawShieldIcon(Canvas canvas, Offset center, double size) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(
      center.dx + size,
      center.dy - size * 0.8,
      center.dx + size,
      center.dy,
    );
    path.quadraticBezierTo(
      center.dx + size,
      center.dy + size * 0.8,
      center.dx,
      center.dy + size,
    );
    path.quadraticBezierTo(
      center.dx - size,
      center.dy + size * 0.8,
      center.dx - size,
      center.dy,
    );
    path.quadraticBezierTo(
      center.dx - size,
      center.dy - size * 0.8,
      center.dx,
      center.dy - size,
    );
    path.close();

    final paint = Paint()
      ..color = accentColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);

    // Checkmark inside shield
    final checkPath = Path()
      ..moveTo(center.dx - size * 0.3, center.dy)
      ..lineTo(center.dx - size * 0.1, center.dy + size * 0.2)
      ..lineTo(center.dx + size * 0.4, center.dy - size * 0.3);

    canvas.drawPath(
      checkPath,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = primaryColor.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _drawKeyIcon(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Key ring
    canvas.drawCircle(
      Offset(center.dx - size * 0.4, center.dy - size * 0.4),
      size * 0.4,
      paint,
    );

    // Key shaft
    canvas.drawLine(
      Offset(center.dx - size * 0.1, center.dy - size * 0.1),
      Offset(center.dx + size * 0.6, center.dy + size * 0.6),
      paint,
    );

    // Key teeth
    canvas.drawLine(
      Offset(center.dx + size * 0.3, center.dy + size * 0.3),
      Offset(center.dx + size * 0.5, center.dy + size * 0.1),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + size * 0.5, center.dy + size * 0.5),
      Offset(center.dx + size * 0.7, center.dy + size * 0.3),
      paint,
    );

    // Glow
    canvas.drawCircle(
      Offset(center.dx - size * 0.4, center.dy - size * 0.4),
      size * 0.4,
      Paint()
        ..color = accentColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawParticles(
    Canvas canvas,
    Offset center,
    double maxRadius,
    double progress,
  ) {
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2 + (progress * math.pi * 0.5);
      final distance =
          maxRadius * 0.8 + (math.sin(progress * math.pi * 3 + i) * 20);
      final x = center.dx + distance * math.cos(angle);
      final y = center.dy + distance * math.sin(angle);

      final opacity = (math.sin(progress * math.pi * 4 + i) * 0.3 + 0.3).clamp(
        0.0,
        0.6,
      );

      canvas.drawCircle(
        Offset(x, y),
        2.5,
        Paint()
          ..color = (i % 2 == 0 ? accentColor : primaryColor).withOpacity(
            opacity,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ForgotPasswordIllustrationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.currentStep != currentStep;
}
