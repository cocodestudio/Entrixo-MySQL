import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/api_config.dart';
import '../../widgets/geometric_loader.dart';

class DailyAttendanceSummary {
  final int total;
  final int present;
  final int absent;
  final List<StudentDailyReport> students;

  DailyAttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.students,
  });
}

class StudentDailyReport {
  final String id;
  final String name;
  final String rollNumber;
  final String? profilePic;
  final String status;
  final Map<String, dynamic>? details;

  StudentDailyReport({
    required this.id,
    required this.name,
    required this.rollNumber,
    this.profilePic,
    required this.status,
    this.details,
  });

  factory StudentDailyReport.fromJson(Map<String, dynamic> json) {
    return StudentDailyReport(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unknown',
      rollNumber: json['roll_number']?.toString() ?? 'N/A',
      profilePic: json['profile_pic']?.toString(),
      status: json['status']?.toString() ?? 'Absent',
      details: json['details'] != null
          ? Map<String, dynamic>.from(json['details'])
          : null,
    );
  }
}

final dailyReportProvider = FutureProvider.autoDispose
    .family<DailyAttendanceSummary?, String>((ref, queryStr) async {
      final parts = queryStr.split('|');
      final dateStr = parts[0];
      final courseId = parts[1];
      final semester = parts[2];
      final subjectId = parts[3];

      if (courseId == 'null' || semester == 'null' || subjectId == 'null') {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("Unauthorized");

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/admin/attendance/daily-report?date=$dateStr&course_id=$courseId&semester=$semester&subject_id=$subjectId',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['summary'] ?? {};
        final List studentsRaw = data['data'] ?? [];

        return DailyAttendanceSummary(
          total: int.tryParse(summary['total'].toString()) ?? 0,
          present: int.tryParse(summary['present'].toString()) ?? 0,
          absent: int.tryParse(summary['absent'].toString()) ?? 0,
          students: studentsRaw
              .map(
                (e) =>
                    StudentDailyReport.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList(),
        );
      } else {
        throw Exception("Failed to load report: ${response.statusCode}");
      }
    });

class AdminDailyAttendanceView extends ConsumerStatefulWidget {
  const AdminDailyAttendanceView({super.key});

  @override
  ConsumerState<AdminDailyAttendanceView> createState() =>
      _AdminDailyAttendanceViewState();
}

class _AdminDailyAttendanceViewState
    extends ConsumerState<AdminDailyAttendanceView> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedCourseId;
  String? _selectedCourseName;
  int? _courseDuration;
  int? _selectedSemester;
  String? _selectedSubjectId;
  String? _selectedSubjectName;

  List<dynamic> _courses = [];
  List<dynamic> _subjects = [];
  bool _isLoadingFilters = true;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/headcount/courses'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _courses = jsonDecode(response.body)['data'] ?? [];
          _isLoadingFilters = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _fetchSubjects() async {
    if (_selectedCourseId == null || _selectedSemester == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final url =
          '${ApiConfig.baseUrl}/subjects?course_id=$_selectedCourseId&semester=$_selectedSemester';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _subjects = jsonDecode(response.body)['data'] ?? [];
          _selectedSubjectId = null;
          _selectedSubjectName = null;
        });
      }
    } catch (e) {
      debugPrint("Subject fetch error: $e");
    }
  }

  void _showSelectionSheet(
    String title,
    List<dynamic> items,
    Function(dynamic) onSelect,
  ) {
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
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 24),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(
                      item['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      onSelect(item);
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

  void _showSemesterSheet() {
    if (_courseDuration == null) return;
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "Select Semester",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _courseDuration! * 2,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  int sem = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedSemester = sem);
                      Navigator.pop(context);
                      _fetchSubjects();
                    },
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "SEM",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$sem",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final queryStr =
        "$dateStr|$_selectedCourseId|$_selectedSemester|$_selectedSubjectId";
    final reportAsync = ref.watch(dailyReportProvider(queryStr));

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
          "Daily Class Report",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _selectedSubjectId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.manage_search_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Select filters to view report",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : reportAsync.when(
                    loading: () => const Center(
                      child: GeometricLoader(size: 50, isDarkMode: false),
                    ),
                    error: (e, st) =>
                        Center(child: Text("Error fetching report: $e")),
                    data: (summary) {
                      if (summary == null || summary.students.isEmpty) {
                        return Center(
                          child: Text(
                            "No students found for this class.",
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        );
                      }
                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildSummaryCards(summary),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _StudentReportCard(
                                  student: summary.students[index],
                                ),
                                childCount: summary.students.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 40)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: _filterBox(
              "Date",
              DateFormat('dd MMM yyyy').format(_selectedDate),
              Icons.calendar_today_rounded,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: () =>
                      _showSelectionSheet("Select Course", _courses, (item) {
                        setState(() {
                          _selectedCourseId = item['id'].toString();
                          _selectedCourseName = item['name'];
                          _courseDuration = item['durationYears'];
                          _selectedSemester = null;
                          _selectedSubjectId = null;
                          _selectedSubjectName = null;
                        });
                      }),
                  child: _filterBox(
                    "Course",
                    _selectedCourseName ?? "Select",
                    Icons.school_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _selectedCourseId == null ? null : _showSemesterSheet,
                  child: _filterBox(
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
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _selectedSemester == null
                ? null
                : () =>
                      _showSelectionSheet("Select Subject", _subjects, (item) {
                        setState(() {
                          _selectedSubjectId = item['id'].toString();
                          _selectedSubjectName = item['name'];
                        });
                      }),
            child: _filterBox(
              "Subject",
              _selectedSubjectName ?? "Select Subject / Lab",
              Icons.book_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterBox(String label, String value, IconData icon) {
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

  Widget _buildSummaryCards(DailyAttendanceSummary summary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              "Total",
              "${summary.total}",
              Colors.black,
              Colors.grey[100]!,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              "Present",
              "${summary.present}",
              const Color(0xFF10B981),
              const Color(0xFF10B981).withOpacity(0.1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              "Absent",
              "${summary.absent}",
              const Color(0xFFEF4444),
              const Color(0xFFEF4444).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentReportCard extends StatelessWidget {
  final StudentDailyReport student;
  const _StudentReportCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final isPresent = student.status == 'Present';
    final badgeColor = isPresent
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: EdgeInsets.zero,
          onExpansionChanged: (expanded) {
            if (expanded) HapticFeedback.selectionClick();
          },
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey[100]!, width: 2),
            ),
            child: ClipOval(
              child: student.profilePic != null
                  ? CachedNetworkImage(
                      imageUrl: student.profilePic!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const Icon(Icons.person, color: Colors.grey),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, color: Colors.grey),
                    )
                  : const Icon(Icons.person, color: Colors.grey),
            ),
          ),
          title: Text(
            student.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          subtitle: Text(
            student.rollNumber,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  student.status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
            ],
          ),
          children: [
            if (isPresent && student.details != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey[100]!)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _detailItem(
                            Icons.access_time_filled_rounded,
                            "Time",
                            student.details!['marked_at'],
                          ),
                        ),
                        Expanded(
                          child: _detailItem(
                            Icons.how_to_reg_rounded,
                            "Method",
                            student.details!['method'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _detailItem(
                            Icons.phone_iphone_rounded,
                            "Device Model",
                            student.details!['device_name'],
                          ),
                        ),
                        Expanded(
                          child: _detailItem(
                            Icons.fingerprint_rounded,
                            "IP/Device ID",
                            student.details!['ip_address'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _detailItem(
                            Icons.computer_rounded,
                            "Lab No",
                            student.details!['lab_no']?.toString() ?? 'N/A',
                          ),
                        ),
                        Expanded(
                          child: _detailItem(
                            Icons.desktop_windows_rounded,
                            "PC No",
                            student.details!['pc_no']?.toString() ?? 'N/A',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.red[300],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "No attendance record found.",
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
