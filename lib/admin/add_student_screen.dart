import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';
import '../utils/api_config.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  bool _isLoading = false;
  bool _isLoadingCourses = true;
  List<dynamic> _coursesList = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedCourseId;
  String _selectedCourseName = 'Select Course';
  int _currentCourseDuration = 0;
  int? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNoController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchCourses() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.courses),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() {
          _coursesList = decoded['data'] ?? decoded;
          _isLoadingCourses = false;
        });
      } else {
        setState(() => _isLoadingCourses = false);
        CustomToast.show(context, "Failed to load courses", isError: true);
      }
    } catch (e) {
      setState(() => _isLoadingCourses = false);
      CustomToast.show(context, "Network Error", isError: true);
    }
  }

  Future<void> _registerStudent() async {
    FocusScope.of(context).unfocus();

    if (_nameController.text.trim().isEmpty ||
        _rollNoController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedCourseId == null ||
        _selectedSemester == null) {
      CustomToast.show(
        context,
        "Please fill all mandatory fields (*)",
        isError: true,
      );
      return;
    }

    final emailText = _emailController.text.trim();
    if (emailText.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(emailText)) {
        CustomToast.show(
          context,
          "Please enter a valid email address",
          isError: true,
        );
        return;
      }
    }

    if (_phoneController.text.trim().length < 10) {
      CustomToast.show(
        context,
        "Please enter a valid phone number",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'phone_number': _phoneController.text.trim(),
          'roll_number': _rollNoController.text.trim().toUpperCase(),
          'course_id': _selectedCourseId,
          'course_name': _selectedCourseName,
          'current_semester': _selectedSemester,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          CustomToast.show(context, "Student Added Successfully!");
          _nameController.clear();
          _rollNoController.clear();
          _emailController.clear();
          _phoneController.clear();
          setState(() {
            _selectedCourseId = null;
            _selectedCourseName = 'Select Course';
            _selectedSemester = null;
          });
          Navigator.pop(context);
        }
      } else {
        String errorMessage = responseData['message'] ?? "Registration failed";
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          errorMessage = errors.values.first[0];
        }
        if (mounted) CustomToast.show(context, errorMessage, isError: true);
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Server Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCourseSelector() {
    if (_isLoadingCourses) {
      CustomToast.show(context, "Loading courses...", isError: false);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Select Course",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _coursesList.isEmpty
                    ? const Center(child: Text("No courses found"))
                    : ListView.separated(
                        controller: controller,
                        itemCount: _coursesList.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 24),
                        itemBuilder: (context, index) {
                          final data = _coursesList[index];
                          final isSelected =
                              _selectedCourseId == data['id'].toString();

                          return _buildSelectionItem(
                            title: data['name'],
                            subtitle:
                                "${data['duration_years'] ?? 4} Years Duration",
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedCourseId = data['id'].toString();
                                _selectedCourseName = data['name'];
                                _currentCourseDuration =
                                    int.tryParse(
                                      data['duration_years'].toString(),
                                    ) ??
                                    4;
                                _selectedSemester = null;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSemesterSelector() {
    if (_selectedCourseId == null) {
      CustomToast.show(context, "Please select a course first", isError: true);
      return;
    }

    final int maxSemesters = _currentCourseDuration * 2;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Select Semester",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: maxSemesters,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 24),
                itemBuilder: (context, index) {
                  final sem = index + 1;
                  return _buildSelectionItem(
                    title: "Semester $sem",
                    isSelected: _selectedSemester == sem,
                    onTap: () {
                      setState(() => _selectedSemester = sem);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionItem({
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? theme.primaryColor.withOpacity(0.08) : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isSelected
                          ? theme.primaryColor
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.primaryColor,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
          "Add Student",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionLabel("Student Details"),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _nameController,
                  label: "Full Name *",
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _rollNoController,
                  label: "Roll Number *",
                  icon: Icons.badge_outlined,
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _emailController,
                  label: "Email Address *",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildPremiumTextField(
                  controller: _phoneController,
                  label: "Phone Number *",
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),

                const SizedBox(height: 32),
                _buildSectionLabel("Academic Info"),
                const SizedBox(height: 16),

                _buildPremiumSelector(
                  label: "Course *",
                  value: _selectedCourseName,
                  icon: Icons.school_outlined,
                  onTap: _showCourseSelector,
                  isSelected: _selectedCourseId != null,
                ),
                const SizedBox(height: 16),

                Opacity(
                  opacity: _selectedCourseId == null ? 0.6 : 1.0,
                  child: _buildPremiumSelector(
                    label: "Semester *",
                    value: _selectedSemester == null
                        ? "Select Semester"
                        : "Semester $_selectedSemester",
                    icon: Icons.layers_outlined,
                    onTap: _selectedCourseId == null
                        ? null
                        : _showSemesterSelector,
                    isSelected: _selectedSemester != null,
                  ),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: theme.primaryColor.withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? GeometricLoader(
                            size: 24,
                            isDarkMode: theme.brightness == Brightness.dark,
                          )
                        : const Text(
                            "Register Student",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: GeometricLoader(size: 60, isDarkMode: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremiumSelector({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.primaryColor.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.primaryColor : Colors.grey[400],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelected) ...[
                    Text(
                      label.replaceAll(" *", ""),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey[800],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
          fontSize: 13,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}
