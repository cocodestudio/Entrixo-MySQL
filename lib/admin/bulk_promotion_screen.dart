import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/api_config.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';

class BulkPromotionScreen extends StatefulWidget {
  const BulkPromotionScreen({super.key});

  @override
  State<BulkPromotionScreen> createState() => _BulkPromotionScreenState();
}

class _BulkPromotionScreenState extends State<BulkPromotionScreen> {
  bool _isLoadingCourses = true;
  bool _isFetchingStudents = false;
  bool _isPromoting = false;

  List<dynamic> _coursesList = [];
  List<dynamic> _studentsList = [];
  Set<String> _selectedStudentIds = {};

  String? _selectedCourseId;
  String? _selectedCourseName;
  int _currentCourseDuration = 0;
  int? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
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
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _coursesList = decoded['data'] ?? [];
            _isLoadingCourses = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingCourses = false);
          CustomToast.show(context, "Failed to load courses", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCourses = false);
        CustomToast.show(context, "Network Error", isError: true);
      }
    }
  }

  Future<void> _fetchStudents() async {
    if (_selectedCourseId == null || _selectedSemester == null) return;

    setState(() {
      _isFetchingStudents = true;
      _studentsList = [];
      _selectedStudentIds.clear();
    });

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/students?course_id=$_selectedCourseId&semester=$_selectedSemester',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final students = decoded['data'] as List<dynamic>;

        if (mounted) {
          setState(() {
            _studentsList = students;
            // Default: Select all students
            _selectedStudentIds = students
                .map((s) => s['id'].toString())
                .toSet();
            _isFetchingStudents = false;
          });
        }
      } else {
        throw Exception("Failed to load students");
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingStudents = false);
        CustomToast.show(context, "Error fetching students", isError: true);
      }
    }
  }

  Future<void> _promoteStudents() async {
    if (_selectedStudentIds.isEmpty) {
      CustomToast.show(
        context,
        "Please select at least one student",
        isError: true,
      );
      return;
    }

    setState(() => _isPromoting = true);

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.promoteStudents),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'course_id': _selectedCourseId,
          'current_semester': _selectedSemester,
          'student_ids': _selectedStudentIds.toList(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CustomToast.show(context, "Students Promoted Successfully!");
          // Reset view after success
          setState(() {
            _selectedSemester = null;
            _studentsList = [];
            _selectedStudentIds.clear();
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? "Failed to promote");
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          e.toString().replaceAll("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPromoting = false);
    }
  }

  void _showCourseSelector() {
    if (_isLoadingCourses) return;

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
            Flexible(
              child: _coursesList.isEmpty
                  ? const Center(child: Text("No courses found"))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _coursesList.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 24),
                      itemBuilder: (context, index) {
                        final data = _coursesList[index];
                        final isSelected =
                            _selectedCourseId == data['id'].toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          title: Text(
                            data['name'],
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.black87,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                )
                              : null,
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
                              _studentsList.clear();
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
    );
  }

  void _showSemesterSelector() {
    if (_selectedCourseId == null) {
      CustomToast.show(context, "Select a course first", isError: true);
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Select Current Semester",
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
                  final isSelected = _selectedSemester == sem;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(
                      "Semester $sem",
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.black87,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedSemester = sem);
                      Navigator.pop(context);
                      _fetchStudents(); // Auto fetch when semester selected
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
          "Promotion",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GestureDetector(
                        onTap: _showCourseSelector,
                        child: _buildFilterBox(
                          "Course",
                          _selectedCourseName ?? "Select Course",
                          Icons.school_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _showSemesterSelector,
                        child: _buildFilterBox(
                          "Semester",
                          _selectedSemester != null
                              ? "Sem $_selectedSemester"
                              : "Select",
                          Icons.layers_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // STUDENT LIST SECTION
          Expanded(
            child: _isFetchingStudents
                ? const Center(
                    child: GeometricLoader(size: 40, isDarkMode: false),
                  )
                : _selectedSemester == null
                ? _buildEmptyState(
                    "Select Course & Semester",
                    "Choose the current batch you want to promote.",
                    Icons.settings_suggest_rounded,
                  )
                : _studentsList.isEmpty
                ? _buildEmptyState(
                    "No Students Found",
                    "There are no active students in this semester.",
                    Icons.group_off_rounded,
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Eligible Students (${_studentsList.length})",
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_selectedStudentIds.length ==
                                      _studentsList.length) {
                                    _selectedStudentIds.clear();
                                  } else {
                                    _selectedStudentIds = _studentsList
                                        .map((s) => s['id'].toString())
                                        .toSet();
                                  }
                                });
                              },
                              child: Text(
                                _selectedStudentIds.length ==
                                        _studentsList.length
                                    ? "Deselect All"
                                    : "Select All",
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _studentsList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final student = _studentsList[index];
                            final String sid = student['id'].toString();
                            final bool isSelected = _selectedStudentIds
                                .contains(sid);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedStudentIds.remove(sid);
                                  } else {
                                    _selectedStudentIds.add(sid);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.primaryColor.withOpacity(0.5)
                                        : Colors.transparent,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            student['roll_number'] ?? 'N/A',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? theme.primaryColor
                                          : Colors.grey[300],
                                      size: 26,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),

      // BOTTOM ACTION BUTTON
      bottomSheet: _studentsList.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isPromoting || _selectedStudentIds.isEmpty)
                        ? null
                        : _promoteStudents,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: _isPromoting
                        ? GeometricLoader(size: 24, isDarkMode: isDarkMode)
                        : Text(
                            "Promote ${_selectedStudentIds.length} Students to Sem ${_selectedSemester! + 1}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String desc, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 60, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
