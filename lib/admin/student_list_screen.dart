import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/api_config.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  String? _selectedCourseId;
  String _selectedCourseName = 'Select Course';
  int _currentCourseDuration = 0;
  int? _selectedSemester;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _coursesList = [];
  List<dynamic> _studentsList = [];
  bool _isLoadingCourses = false;
  bool _isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchCourses() async {
    setState(() => _isLoadingCourses = true);
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
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _coursesList = data['data'] ?? []);
      }
    } catch (e) {
      if (mounted)
        CustomToast.show(context, "Failed to load courses", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _fetchStudents() async {
    if (_selectedCourseId == null || _selectedSemester == null) return;

    setState(() => _isLoadingStudents = true);
    try {
      final token = await _getToken();
      final uri = Uri.parse(
        "${ApiConfig.students}?course_id=$_selectedCourseId&semester=$_selectedSemester",
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _studentsList = data['data'] ?? []);
      } else {
        if (mounted)
          CustomToast.show(context, "Failed to fetch students", isError: true);
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Network Error", isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _resetDeviceBinding(String uid) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Reset Device Binding?"),
        content: const Text(
          "This will allow the student to login and mark attendance from a new device.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final token = await _getToken();
                final response = await http.post(
                  Uri.parse("${ApiConfig.baseUrl}/students/reset-device"),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({'student_id': uid}),
                );

                if (response.statusCode == 200) {
                  if (mounted)
                    CustomToast.show(
                      context,
                      "Device binding reset successfully",
                    );
                } else {
                  if (mounted)
                    CustomToast.show(
                      context,
                      "Failed to reset device",
                      isError: true,
                    );
                }
              } catch (e) {
                if (mounted)
                  CustomToast.show(context, "Error: $e", isError: true);
              }
            },
            child: const Text(
              "Reset",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCourseSelector({
    required Function(String id, String name, int duration) onSelect,
  }) {
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
                child: _isLoadingCourses
                    ? const Center(
                        child: GeometricLoader(size: 30, isDarkMode: false),
                      )
                    : ListView.separated(
                        controller: controller,
                        itemCount: _coursesList.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 24),
                        itemBuilder: (context, index) {
                          final data = _coursesList[index];
                          final String id = data['id'].toString();
                          final String name = data['name'] ?? 'Unknown';
                          final int duration =
                              int.tryParse(data['duration_years'].toString()) ??
                              4;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 4,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "$duration Years",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            onTap: () {
                              onSelect(id, name, duration);
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

  void _showSemesterSelector({
    required int duration,
    required Function(int sem) onSelect,
  }) {
    final int maxSemesters = duration * 2;

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
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(
                      "Semester $sem",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      onSelect(sem);
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

  void _showStudentActionSheet(Map<String, dynamic> data, String uid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Manage Student",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
            _buildActionTile(
              icon: Icons.edit_rounded,
              color: Colors.blueAccent,
              label: "Edit Details",
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(data, uid);
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.phonelink_erase_rounded,
              color: Colors.orange,
              label: "Reset Device Binding",
              onTap: () {
                Navigator.pop(context);
                _resetDeviceBinding(uid);
              },
            ),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.delete_outline_rounded,
              color: Colors.redAccent,
              label: "Delete Student",
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _deleteStudent(uid);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFFF5F5)
              : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStudent(String uid) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Student"),
        content: const Text("Are you sure? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final token = await _getToken();
                final response = await http.delete(
                  Uri.parse("${ApiConfig.students}/$uid"),
                  headers: {
                    'Accept': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                );

                if (response.statusCode == 200) {
                  if (mounted)
                    CustomToast.show(context, "Student deleted successfully");
                  _fetchStudents();
                } else {
                  if (mounted)
                    CustomToast.show(
                      context,
                      "Failed to delete student",
                      isError: true,
                    );
                }
              } catch (e) {
                if (mounted)
                  CustomToast.show(context, "Error: $e", isError: true);
              }
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(Map<String, dynamic> data, String uid) {
    final nameCtrl = TextEditingController(text: data['name']);
    final rollCtrl = TextEditingController(text: data['roll_number']);

    String editCourseId = data['course_id'].toString();
    String editCourseName = data['course_name'] ?? _selectedCourseName;
    int editSemester = int.tryParse(data['current_semester'].toString()) ?? 1;
    int editDuration = _currentCourseDuration > 0 ? _currentCourseDuration : 4;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
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
                    "Update Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: rollCtrl,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: "Roll Number",
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEditSelector(
                    label: "Course",
                    value: editCourseName,
                    icon: Icons.school_outlined,
                    onTap: () {
                      _showCourseSelector(
                        onSelect: (id, name, duration) {
                          setSheetState(() {
                            editCourseId = id;
                            editCourseName = name;
                            editDuration = duration;
                            editSemester = 1;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildEditSelector(
                    label: "Semester",
                    value: "Semester $editSemester",
                    icon: Icons.layers_outlined,
                    onTap: () {
                      _showSemesterSelector(
                        duration: editDuration,
                        onSelect: (sem) {
                          setSheetState(() {
                            editSemester = sem;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final token = await _getToken();
                          final response = await http.put(
                            Uri.parse("${ApiConfig.students}/$uid"),
                            headers: {
                              'Content-Type': 'application/json',
                              'Accept': 'application/json',
                              'Authorization': 'Bearer $token',
                            },
                            body: jsonEncode({
                              'name': nameCtrl.text.trim(),
                              'roll_number': rollCtrl.text.trim().toUpperCase(),
                              'course_id': editCourseId,
                              'current_semester': editSemester,
                            }),
                          );

                          if (response.statusCode == 200) {
                            if (mounted) {
                              Navigator.pop(context);
                              CustomToast.show(context, "Student Updated");
                              _fetchStudents();
                            }
                          } else {
                            if (mounted)
                              CustomToast.show(
                                context,
                                "Update Failed",
                                isError: true,
                              );
                          }
                        } catch (e) {
                          if (mounted)
                            CustomToast.show(
                              context,
                              "Error: $e",
                              isError: true,
                            );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.4),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditSelector({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.black),
          ],
        ),
      ),
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
          title: Text(
            "Student Directory",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
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
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
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
                        child: _buildFilterChip(
                          label: _selectedCourseName,
                          icon: Icons.school_rounded,
                          isSelected: _selectedCourseId != null,
                          onTap: () {
                            _showCourseSelector(
                              onSelect: (id, name, duration) {
                                setState(() {
                                  _selectedCourseId = id;
                                  _selectedCourseName = name;
                                  _currentCourseDuration = duration;
                                  _selectedSemester = null;
                                  _studentsList.clear();
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterChip(
                          label: _selectedSemester == null
                              ? "Semester"
                              : "Sem $_selectedSemester",
                          icon: Icons.layers_rounded,
                          isSelected: _selectedSemester != null,
                          onTap: _selectedCourseId == null
                              ? null
                              : () {
                                  _showSemesterSelector(
                                    duration: _currentCourseDuration,
                                    onSelect: (sem) {
                                      setState(() => _selectedSemester = sem);
                                      _fetchStudents();
                                    },
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                  if (_selectedCourseId != null &&
                      _selectedSemester != null) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(
                        () => _searchQuery = val.trim().toLowerCase(),
                      ),
                      decoration: InputDecoration(
                        hintText: "Search by Roll No or Phone...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: (_selectedCourseId == null || _selectedSemester == null)
                  ? _buildEmptyState(
                      "Select Course & Semester",
                      "To view the student list, please apply filters above.",
                      Icons.filter_alt_off_rounded,
                    )
                  : _isLoadingStudents
                  ? const Center(
                      child: GeometricLoader(size: 40, isDarkMode: false),
                    )
                  : _studentsList.isEmpty
                  ? _buildEmptyState(
                      "No Students Found",
                      "No students registered in this class yet.",
                      Icons.people_outline_rounded,
                    )
                  : _buildStudentsList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsList(ThemeData theme) {
    final filteredList = _studentsList.where((data) {
      final roll = (data['roll_number'] ?? "").toString().toLowerCase();
      final phone = (data['phone_number'] ?? "").toString().toLowerCase();
      return _searchQuery.isEmpty ||
          roll.contains(_searchQuery) ||
          phone.contains(_searchQuery);
    }).toList();

    if (filteredList.isEmpty) {
      return _buildEmptyState(
        "No Match Found",
        "Try searching with a different roll number.",
        Icons.search_off_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final data = filteredList[index];
        final String uid = data['id'].toString();
        final bool isManual =
            data['is_manual_entry'] == true || data['is_manual_entry'] == 1;
        final String initials = (data['name'] ?? "S")
            .toString()
            .substring(0, 1)
            .toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: isManual
                  ? Colors.orange.withOpacity(0.1)
                  : theme.primaryColor.withOpacity(0.1),
              backgroundImage:
                  (data['profile_pic'] != null &&
                      data['profile_pic'].toString().isNotEmpty)
                  ? NetworkImage(data['profile_pic'])
                  : null,
              child:
                  (data['profile_pic'] == null ||
                      data['profile_pic'].toString().isEmpty)
                  ? Text(
                      initials,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isManual ? Colors.orange : theme.primaryColor,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    data['name'] ?? "Unknown",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "VERIFIED",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.badge_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    data['roll_number'] ?? "N/A",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              color: Colors.grey[400],
              onPressed: () => _showStudentActionSheet(data, uid),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.5)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
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
              child: Icon(icon, size: 48, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
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
