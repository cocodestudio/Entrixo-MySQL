import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import '../utils/custom_toast.dart';
import '../widgets/geometric_loader.dart';
import 'add_lab_Screen.dart';

class AcademicSetupScreen extends StatefulWidget {
  const AcademicSetupScreen({super.key});

  @override
  State<AcademicSetupScreen> createState() => _AcademicSetupScreenState();
}

class _AcademicSetupScreenState extends State<AcademicSetupScreen> {
  String? _selectedCourseId;
  String _selectedCourseName = '';
  int _selectedCourseDuration = 4;
  int _selectedSemester = 1;

  bool _isLoading = false;
  bool _isFetchingInitial = true;
  bool _isFetchingSubjects = false;

  String? _viewingSessionId;
  String? _activeSessionId;
  String _viewingSessionName = "Loading...";

  List<dynamic> _sessionsList = [];
  List<dynamic> _coursesList = [];
  List<dynamic> _subjectsList = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _loadInitialData() async {
    setState(() => _isFetchingInitial = true);
    await Future.wait([_fetchSessions(), _fetchCourses()]);

    if (_sessionsList.isNotEmpty) {
      try {
        final activeSession = _sessionsList.firstWhere(
          (s) => s['status'] == 'Active',
        );
        _activeSessionId = activeSession['id'].toString();
        _viewingSessionId = _activeSessionId;
        _viewingSessionName =
            activeSession['session_name'] ?? activeSession['sessionName'];
      } catch (e) {
        _activeSessionId = null;
        _viewingSessionId = _sessionsList.first['id'].toString();
        _viewingSessionName =
            _sessionsList.first['session_name'] ??
            _sessionsList.first['sessionName'];
      }
    }

    if (_coursesList.isNotEmpty && _selectedCourseId == null) {
      _selectedCourseId = _coursesList.first['id'].toString();
      _selectedCourseName = _coursesList.first['name'];
      _selectedCourseDuration =
          int.tryParse(_coursesList.first['duration_years'].toString()) ?? 4;
      _selectedSemester = 1;
    }

    if (mounted) {
      setState(() => _isFetchingInitial = false);
      _fetchSubjects();
    }
  }

  Future<void> _fetchSessions() async {
    try {
      final token = await _getToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/sessions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        _sessionsList = json.decode(response.body)['data'];
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final token = await _getToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse(ApiConfig.courses),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        _coursesList = json.decode(response.body)['data'];
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _fetchSubjects() async {
    if (_selectedCourseId == null || _viewingSessionId == null) return;

    setState(() => _isFetchingSubjects = true);
    try {
      final token = await _getToken();
      if (token == null) return;

      final uri = Uri.parse(
        '${ApiConfig.subjects}?course_id=$_selectedCourseId&semester=$_selectedSemester&session_id=$_viewingSessionId',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _subjectsList = json.decode(response.body)['data'];
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _isFetchingSubjects = false);
    }
  }

  Future<void> _addCourse(String name, int years) async {
    if (name.trim().isEmpty) {
      _showSnack("Please enter a course name", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.courses),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({'name': name.trim(), 'duration_years': years}),
      );

      if (response.statusCode == 201) {
        await _fetchCourses();
        if (mounted) {
          Navigator.pop(context);
          setState(() {
            _selectedCourseId = _coursesList.last['id'].toString();
            _selectedCourseName = _coursesList.last['name'];
            _selectedCourseDuration = years;
            _selectedSemester = 1;
          });
          _fetchSubjects();
          _showSnack("Course added successfully!");
        }
      } else {
        final error = json.decode(response.body);
        _showSnack(error['message'] ?? "Error adding course", isError: true);
      }
    } catch (e) {
      _showSnack("Network Error", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _addSubject(
    String name,
    String code,
    String facultyName,
    List<Map<String, dynamic>> schedule,
  ) async {
    if (name.trim().isEmpty ||
        code.trim().isEmpty ||
        facultyName.trim().isEmpty) {
      _showSnack("Please fill all fields", isError: true);
      return false;
    }
    if (_selectedCourseId == null) {
      _showSnack("No course selected", isError: true);
      return false;
    }
    if (_activeSessionId == null) {
      _showSnack("No Active Session Found!", isError: true);
      return false;
    }
    if (schedule.isEmpty) {
      _showSnack("Please generate a schedule first", isError: true);
      return false;
    }

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.subjects),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': name.trim(),
          'code': code.trim().toUpperCase(),
          'faculty_name': facultyName.trim(),
          'course_id': _selectedCourseId,
          'semester': _selectedSemester,
          'session_id': _activeSessionId,
          'schedule': schedule,
        }),
      );

      if (response.statusCode == 201) {
        await _fetchSubjects();
        if (mounted) {
          _showSnack("Lab & Schedule added successfully!");
        }
        return true;
      } else {
        final error = json.decode(response.body);
        _showSnack(error['message'] ?? "Error adding subject", isError: true);
        return false;
      }
    } catch (e) {
      _showSnack("Network Error", isError: true);
      return false;
    }
  }

  Future<void> _deleteSubject(String subjectId) async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${ApiConfig.subjects}/$subjectId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await _fetchSubjects();
        _showSnack("Lab removed");
      } else {
        _showSnack("Failed to delete", isError: true);
      }
    } catch (e) {
      _showSnack("Network Error", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    CustomToast.show(context, msg, isError: isError);
  }

  void _showViewScheduleSheet(List<dynamic> schedule, String labName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
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
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            "${schedule.length} Active Sessions",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: schedule.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = schedule[index];
                    final DateTime date = DateTime.parse(
                      item['date'].toString(),
                    );
                    final dateStr = "${date.day}/${date.month}/${date.year}";
                    const days = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ];
                    final dayName = days[date.weekday - 1];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  dayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${item['startTime'] ?? item['start_time']} - ${item['endTime'] ?? item['end_time']}",
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
                        ],
                      ),
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

  void _showSessionSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Select Academic Session",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sessionsList.length,
                itemBuilder: (context, index) {
                  final data = _sessionsList[index];
                  final id = data['id'].toString();
                  final isSelected = _viewingSessionId == id;
                  final isActive = data['status'] == 'Active';

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _viewingSessionId = id;
                        _viewingSessionName =
                            data['session_name'] ?? data['sessionName'];
                      });
                      _fetchSubjects();
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.05)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            isActive
                                ? Icons.verified_rounded
                                : Icons.history_rounded,
                            color: isActive ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              data['session_name'] ?? data['sessionName'],
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.black87,
                              ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCourseSheet() {
    final TextEditingController nameController = TextEditingController();
    int selectedYears = 3;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
              const Text(
                "New Course Setup",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nameController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Course Name",
                  hintText: "e.g. B.Tech CS",
                  labelStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.school_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Course Duration",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final years = index + 1;
                    final isSelected = selectedYears == years;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedYears = years),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "$years Years",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[800],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _addCourse(nameController.text, selectedYears),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? GeometricLoader(size: 24, isDarkMode: isDarkMode)
                      : const Text(
                          "Create Course",
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.layers_clear_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No Labs Configured",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap '+ Add Lab' to setup subjects",
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectTile(
    Map<String, dynamic> data,
    String id,
    ThemeData theme,
    bool isReadOnly,
  ) {
    final name = data['name'] ?? 'Unknown';
    final code = data['code'] ?? '---';
    final faculty = data['faculty_name'] ?? 'N/A';
    final schedule = data['schedule'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor.withOpacity(0.15),
                  theme.primaryColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              code.split('-').last,
              style: TextStyle(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Dr. $faculty",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showViewScheduleSheet(schedule, name),
            icon: Icon(
              Icons.calendar_month_outlined,
              color: theme.primaryColor.withOpacity(0.7),
              size: 22,
            ),
            tooltip: "View Schedule",
          ),
          if (!isReadOnly)
            IconButton(
              onPressed: () => _deleteSubject(id),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red[200],
                size: 20,
              ),
              splashRadius: 24,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingInitial) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: Center(
          child: GeometricLoader(
            size: 40,
            isDarkMode: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDarkMode = theme.brightness == Brightness.dark;
    final bool isReadOnly = _viewingSessionId != _activeSessionId;

    return Stack(
      children: [
        Scaffold(
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
              "Academic Setup",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          floatingActionButton:
              (_activeSessionId != null &&
                  !isReadOnly &&
                  _selectedCourseId != null)
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomPadding > 0 ? 0 : 20),
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddLabScreen(onSave: _addSubject),
                        ),
                      );
                    },
                    backgroundColor: theme.primaryColor,
                    elevation: 2,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: const Text(
                      "Add Lab",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : null,
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () => _showSessionSelector(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Academic Session",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _viewingSessionName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: theme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Department Course"),
                      IconButton(
                        onPressed: _showAddCourseSheet,
                        icon: Icon(Icons.add_circle, color: theme.primaryColor),
                        tooltip: "New Course",
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: _coursesList.isEmpty
                      ? Center(
                          child: Text(
                            "No courses setup yet.",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 4,
                          ),
                          clipBehavior: Clip.none,
                          itemCount: _coursesList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final doc = _coursesList[index];
                            final isSelected =
                                _selectedCourseId == doc['id'].toString();
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCourseId = doc['id'].toString();
                                  _selectedCourseName = doc['name'];
                                  _selectedCourseDuration =
                                      int.tryParse(
                                        doc['duration_years'].toString(),
                                      ) ??
                                      4;
                                  _selectedSemester = 1;
                                });
                                _fetchSubjects();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.primaryColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected
                                          ? theme.primaryColor.withOpacity(0.3)
                                          : Colors.grey.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    doc['name'],
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[700],
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSectionTitle("Semester"),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    clipBehavior: Clip.none,
                    itemCount: _selectedCourseDuration * 2,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final sem = index + 1;
                      final isSelected = _selectedSemester == sem;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedSemester = sem);
                          _fetchSubjects();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? theme.colorScheme.secondary
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.withOpacity(0.1),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? theme.colorScheme.secondary.withOpacity(
                                        0.4,
                                      )
                                    : Colors.grey.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "$sem",
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
                if (_selectedCourseId != null && _viewingSessionId != null)
                  _isFetchingSubjects
                      ? Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Center(
                            child: GeometricLoader(
                              size: 30,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        )
                      : _subjectsList.isEmpty
                      ? (isReadOnly
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text(
                                    "No data in this past session.",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : _buildEmptyState())
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.fromLTRB(
                            24,
                            0,
                            24,
                            bottomPadding + 80,
                          ),
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _subjectsList.length,
                          itemBuilder: (context, index) {
                            final data = _subjectsList[index];
                            final id = data['id'].toString();
                            return _buildSubjectTile(
                              data,
                              id,
                              theme,
                              isReadOnly,
                            );
                          },
                        ),
              ],
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: GeometricLoader(size: 60, isDarkMode: isDarkMode),
            ),
          ),
      ],
    );
  }
}