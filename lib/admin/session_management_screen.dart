import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import '../widgets/geometric_loader.dart';
import '../utils/custom_toast.dart';

class SessionManagementScreen extends StatefulWidget {
  const SessionManagementScreen({super.key});

  @override
  State<SessionManagementScreen> createState() =>
      _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  bool _isLoading = false;
  bool _isFetchingData = true;
  List<dynamic> _sessionsList = [];
  List<dynamic> _coursesList = [];
  List<String> _academicYears = ['All'];
  String _selectedAcademicYear = 'All';

  final TextEditingController _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  String _selectedCourseId = 'ALL';
  String _selectedCourseName = 'All Courses (Global)';
  String _selectedSemester = 'ALL';
  int _currentCourseDuration = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isFetchingData = true);
    await Future.wait([_fetchSessions(), _fetchCourses()]);
    if (mounted) {
      setState(() => _isFetchingData = false);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  void _extractAcademicYears(List<dynamic> data) {
    Set<String> years = {'All'};
    for (var item in data) {
      if (item['academic_year'] != null) {
        years.add(item['academic_year'].toString());
      }
    }
    setState(() {
      _academicYears = years.toList();
    });
  }

  Future<void> _fetchSessions() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/sessions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _sessionsList = data['data'];
          });
          _extractAcademicYears(_sessionsList);
        }
      }
    } catch (e) {
      if (mounted)
        CustomToast.show(context, "Failed to load sessions", isError: true);
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/courses'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _coursesList = data['data'] ?? data;
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isStart,
    StateSetter setSheetState,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? (_startDate ?? DateTime.now())),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setSheetState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _createSession() async {
    final String sessionName = _nameController.text.trim();

    if (sessionName.isEmpty || _startDate == null || _endDate == null) {
      CustomToast.show(
        context,
        "Please fill all required fields",
        isError: true,
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      CustomToast.show(
        context,
        "End date cannot be before start date",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();

      String targetDescription;
      if (_selectedCourseId == 'ALL') {
        targetDescription = "Global Session (All Courses)";
      } else {
        targetDescription = _selectedSemester == 'ALL'
            ? "$_selectedCourseName • All Semesters"
            : "$_selectedCourseName • Semester $_selectedSemester";
      }

      int startYear = _startDate!.year;
      int nextYearShort = (startYear + 1) % 100;
      String academicYear = "$startYear-$nextYearShort";

      final Map<String, dynamic> requestBody = {
        'session_name': sessionName,
        'academic_year': academicYear,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'course_id': _selectedCourseId,
        'course_name': _selectedCourseName,
        'target_semester': _selectedSemester,
        'description': targetDescription,
      };

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/sessions'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        _nameController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
          _selectedCourseId = 'ALL';
          _selectedCourseName = 'All Courses (Global)';
          _selectedSemester = 'ALL';
        });

        await _fetchSessions();

        if (mounted) {
          Navigator.pop(context);
          CustomToast.show(context, "Session Activated Successfully!");
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          CustomToast.show(
            context,
            errorData['message'] ?? "Failed to create session",
            isError: true,
          );
        }
      }
    } on SocketException {
      if (mounted) CustomToast.show(context, "Network Error", isError: true);
    } catch (e) {
      if (mounted) CustomToast.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSession(String sessionId, String currentStatus) async {
    final String sessionName = _nameController.text.trim();

    if (sessionName.isEmpty || _startDate == null || _endDate == null) {
      CustomToast.show(
        context,
        "Please fill all required fields",
        isError: true,
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      CustomToast.show(
        context,
        "End date cannot be before start date",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();

      String targetDescription;
      if (_selectedCourseId == 'ALL') {
        targetDescription = "Global Session (All Courses)";
      } else {
        targetDescription = _selectedSemester == 'ALL'
            ? "$_selectedCourseName • All Semesters"
            : "$_selectedCourseName • Semester $_selectedSemester";
      }

      int startYear = _startDate!.year;
      int nextYearShort = (startYear + 1) % 100;
      String academicYear = "$startYear-$nextYearShort";

      final Map<String, dynamic> requestBody = {
        'session_name': sessionName,
        'academic_year': academicYear,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        'course_id': _selectedCourseId,
        'course_name': _selectedCourseName,
        'target_semester': _selectedSemester,
        'description': targetDescription,
        'status': currentStatus,
      };

      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/sessions/$sessionId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _nameController.clear();
        setState(() {
          _startDate = null;
          _endDate = null;
          _selectedCourseId = 'ALL';
          _selectedCourseName = 'All Courses (Global)';
          _selectedSemester = 'ALL';
        });

        await _fetchSessions();

        if (mounted) {
          Navigator.pop(context);
          CustomToast.show(context, "Session Updated Successfully!");
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          CustomToast.show(
            context,
            errorData['message'] ?? "Failed to update session",
            isError: true,
          );
        }
      }
    } on SocketException {
      if (mounted) CustomToast.show(context, "Network Error", isError: true);
    } catch (e) {
      if (mounted) CustomToast.show(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Session"),
        content: const Text(
          "Are you sure you want to delete this session? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final token = await _getToken();
        final response = await http
            .delete(
              Uri.parse('${ApiConfig.baseUrl}/sessions/$sessionId'),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          await _fetchSessions();
          if (mounted) {
            CustomToast.show(context, "Session Deleted Successfully");
          }
        } else {
          if (mounted)
            CustomToast.show(context, "Failed to delete", isError: true);
        }
      } catch (e) {
        if (mounted) {
          CustomToast.show(context, "Error: $e", isError: true);
        }
      }
    }
  }

  void _showYearSelector() {
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
                "Select Academic Year",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _academicYears.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 24),
                itemBuilder: (context, index) {
                  final year = _academicYears[index];
                  final isSelected = _selectedAcademicYear == year;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(
                      year == 'All' ? "All Sessions" : year,
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
                      setState(() => _selectedAcademicYear = year);
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

  void _showCourseSelector(StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
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
              child: ListView(
                shrinkWrap: true,
                children: [
                  _buildSelectionItem(
                    title: "All Courses (Global)",
                    isSelected: _selectedCourseId == 'ALL',
                    onTap: () {
                      setSheetState(() {
                        _selectedCourseId = 'ALL';
                        _selectedCourseName = 'All Courses (Global)';
                        _currentCourseDuration = 0;
                        _selectedSemester = 'ALL';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(height: 1),
                  if (_coursesList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: Text("No courses found")),
                    ),
                  ..._coursesList.map((data) {
                    return _buildSelectionItem(
                      title: data['name'],
                      subtitle:
                          "${data['duration_years'] ?? data['durationYears']} Years Duration",
                      isSelected: _selectedCourseId == data['id'].toString(),
                      onTap: () {
                        setSheetState(() {
                          _selectedCourseId = data['id'].toString();
                          _selectedCourseName = data['name'];
                          _currentCourseDuration =
                              int.tryParse(
                                data['duration_years']?.toString() ??
                                    data['durationYears']?.toString() ??
                                    '0',
                              ) ??
                              0;
                          _selectedSemester = 'ALL';
                        });
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSemesterSelector(StateSetter setSheetState) {
    if (_selectedCourseId == 'ALL') {
      CustomToast.show(
        context,
        "Select a specific course to filter by semester",
        isError: true,
      );
      return;
    }

    final int maxSemesters = _currentCourseDuration * 2;
    final List<String> semesterOptions = ['ALL'];
    for (int i = 1; i <= maxSemesters; i++) {
      semesterOptions.add(i.toString());
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: semesterOptions.length,
                itemBuilder: (context, index) {
                  final sem = semesterOptions[index];
                  final label = sem == 'ALL'
                      ? "All Semesters"
                      : "Semester $sem";
                  return _buildSelectionItem(
                    title: label,
                    isSelected: _selectedSemester == sem,
                    onTap: () {
                      setSheetState(() => _selectedSemester = sem);
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected
            ? Theme.of(context).primaryColor.withOpacity(0.05)
            : null,
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
                          : FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.black87,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(context).primaryColor,
              ),
          ],
        ),
      ),
    );
  }

  void _showSessionSheet({Map<String, dynamic>? editData}) {
    if (editData != null) {
      _nameController.text =
          editData['session_name'] ?? editData['sessionName'] ?? '';
      _startDate = DateTime.tryParse(
        editData['start_date'] ?? editData['startDate'] ?? '',
      );
      _endDate = DateTime.tryParse(
        editData['end_date'] ?? editData['endDate'] ?? '',
      );
      _selectedCourseId = editData['course_id']?.toString() ?? 'ALL';
      _selectedCourseName = editData['course_name'] ?? 'All Courses (Global)';
      _selectedSemester = editData['target_semester']?.toString() ?? 'ALL';

      if (_selectedCourseId != 'ALL') {
        final course = _coursesList.firstWhere(
          (c) => c['id'].toString() == _selectedCourseId,
          orElse: () => null,
        );
        if (course != null) {
          _currentCourseDuration =
              int.tryParse(course['duration_years']?.toString() ?? '0') ?? 0;
        }
      }
    } else {
      _nameController.clear();
      _startDate = null;
      _endDate = null;
      _selectedCourseId = 'ALL';
      _selectedCourseName = 'All Courses (Global)';
      _selectedSemester = 'ALL';
      _currentCourseDuration = 0;
    }

    final isEdit = editData != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
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
              Text(
                isEdit ? "Edit Academic Session" : "New Academic Session",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Define the active period for attendance.",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Session Name",
                  hintText: "e.g. Even Sem 2026",
                  prefixIcon: const Icon(Icons.edit_calendar_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await _selectDate(context, true, setSheetState);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _startDate == null
                                    ? "Start Date"
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_startDate!),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _startDate == null
                                      ? Colors.grey
                                      : Colors.black87,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await _selectDate(context, false, setSheetState);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_rounded,
                              size: 20,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _endDate == null
                                    ? "End Date"
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_endDate!),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _endDate == null
                                      ? Colors.grey
                                      : Colors.black87,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Applicability",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showCourseSelector(setSheetState),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: Colors.grey[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedCourseName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: _selectedCourseId == 'ALL' ? 0.5 : 1.0,
                child: GestureDetector(
                  onTap: _selectedCourseId == 'ALL'
                      ? null
                      : () => _showSemesterSelector(setSheetState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.layers_outlined,
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedCourseId == 'ALL'
                                ? "All Semesters (Global)"
                                : (_selectedSemester == 'ALL'
                                      ? "All Semesters"
                                      : "Semester $_selectedSemester"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_selectedCourseId != 'ALL')
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (isEdit
                            ? () => _updateSession(
                                editData['id'].toString(),
                                editData['status'],
                              )
                            : _createSession),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEdit
                        ? Colors.blueAccent
                        : Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor:
                        (isEdit
                                ? Colors.blueAccent
                                : Theme.of(context).primaryColor)
                            .withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? GeometricLoader(
                          size: 24,
                          isDarkMode:
                              Theme.of(context).brightness == Brightness.dark,
                        )
                      : Text(
                          isEdit ? "Save Changes" : "Activate Session",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final filteredSessions = _selectedAcademicYear == 'All'
        ? _sessionsList
        : _sessionsList
              .where((s) => s['academic_year'] == _selectedAcademicYear)
              .toList();

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
          "Academic Sessions",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 20),
        child: FloatingActionButton.extended(
          onPressed: () => _showSessionSheet(),
          backgroundColor: theme.primaryColor,
          elevation: 2,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            "New Session",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: GestureDetector(
              onTap: _showYearSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Academic Year",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          _selectedAcademicYear == 'All'
                              ? "All Sessions"
                              : _selectedAcademicYear,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isFetchingData
                ? const Center(
                    child: GeometricLoader(size: 40, isDarkMode: false),
                  )
                : filteredSessions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      10,
                      24,
                      bottomPadding + 100,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredSessions.length,
                    itemBuilder: (context, index) {
                      final data = filteredSessions[index];
                      final bool isActive = data['status'] == 'Active';
                      final DateTime start = DateTime.parse(
                        data['start_date'] ?? data['startDate'],
                      );
                      final DateTime end = DateTime.parse(
                        data['end_date'] ?? data['endDate'],
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: isActive
                              ? Border.all(color: theme.primaryColor, width: 2)
                              : Border.all(color: Colors.transparent),
                          boxShadow: [
                            BoxShadow(
                              color: isActive
                                  ? theme.primaryColor.withOpacity(0.15)
                                  : Colors.black.withOpacity(0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? theme.primaryColor.withOpacity(0.1)
                                        : Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.verified_rounded
                                        : Icons.history_rounded,
                                    color: isActive
                                        ? theme.primaryColor
                                        : Colors.grey[400],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['session_name'] ??
                                            data['sessionName'] ??
                                            '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.date_range_rounded,
                                            size: 14,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isActive ? "ACTIVE" : "ENDED",
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.green
                                              : Colors.grey[500],
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              _showSessionSheet(editData: data),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.edit_rounded,
                                              size: 18,
                                              color: Colors.blueAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _deleteSession(
                                            data['id'].toString(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.hub_outlined,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      data['description'] ??
                                          (data['course_id'] == 'ALL'
                                              ? "Global Session"
                                              : "Specific Course Session"),
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
              child: Icon(
                Icons.calendar_month_outlined,
                size: 60,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Academic Sessions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create a session to start tracking\nattendance and activities.",
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