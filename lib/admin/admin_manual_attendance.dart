import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import '../utils/custom_toast.dart';

class ManualAttendanceState {
  final bool isLoading;
  final String? selectedCourseId;
  final int? selectedSemester;
  final String? selectedSubjectId;
  final DateTime selectedDate;
  final List<Map<String, dynamic>> students;
  final Map<String, String> attendanceStatus;
  final String? errorMessage;
  final String? activeSessionId;
  final String? selectedCourseName;
  final String? selectedSubjectName;

  ManualAttendanceState({
    this.isLoading = false,
    this.selectedCourseId,
    this.selectedSemester,
    this.selectedSubjectId,
    required this.selectedDate,
    this.students = const [],
    this.attendanceStatus = const {},
    this.errorMessage,
    this.activeSessionId,
    this.selectedCourseName,
    this.selectedSubjectName,
  });

  ManualAttendanceState copyWith({
    bool? isLoading,
    String? selectedCourseId,
    int? selectedSemester,
    String? selectedSubjectId,
    DateTime? selectedDate,
    List<Map<String, dynamic>>? students,
    Map<String, String>? attendanceStatus,
    String? errorMessage,
    String? activeSessionId,
    String? selectedCourseName,
    String? selectedSubjectName,
  }) {
    return ManualAttendanceState(
      isLoading: isLoading ?? this.isLoading,
      selectedCourseId: selectedCourseId ?? this.selectedCourseId,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      selectedSubjectId: selectedSubjectId ?? this.selectedSubjectId,
      selectedDate: selectedDate ?? this.selectedDate,
      students: students ?? this.students,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      errorMessage: errorMessage,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      selectedCourseName: selectedCourseName ?? this.selectedCourseName,
      selectedSubjectName: selectedSubjectName ?? this.selectedSubjectName,
    );
  }
}

final manualAttendanceProvider =
    StateNotifierProvider.autoDispose<
      ManualAttendanceController,
      ManualAttendanceState
    >((ref) {
      return ManualAttendanceController();
    });

class ManualAttendanceController extends StateNotifier<ManualAttendanceState> {
  ManualAttendanceController()
    : super(ManualAttendanceState(selectedDate: DateTime.now())) {
    _checkActiveSession();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _checkActiveSession() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _getToken();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/active-session'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state = state.copyWith(
          isLoading: false,
          activeSessionId: data['data']['id'].toString(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              "CRITICAL: No Active Academic Session found! Please create one first.",
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Network error: $e",
      );
    }
  }

  void setCourse(String? courseId, String? courseName) {
    state = state.copyWith(
      selectedCourseId: courseId,
      selectedCourseName: courseName,
      selectedSubjectId: null,
      selectedSubjectName: null,
      students: [],
    );
  }

  void setSemester(int? semester) {
    state = state.copyWith(
      selectedSemester: semester,
      selectedSubjectId: null,
      selectedSubjectName: null,
      students: [],
    );
  }

  void setSubject(String? subjectId, String? subjectName) {
    state = state.copyWith(
      selectedSubjectId: subjectId,
      selectedSubjectName: subjectName,
    );
    if (subjectId != null) {
      _fetchStudentsAndAttendance();
    }
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    if (state.selectedSubjectId != null) {
      _fetchStudentsAndAttendance();
    }
  }

  Future<void> _fetchStudentsAndAttendance() async {
    if (state.selectedCourseId == null ||
        state.selectedSemester == null ||
        state.selectedSubjectId == null ||
        state.activeSessionId == null)
      return;

    state = state.copyWith(isLoading: true);

    try {
      final token = await _getToken();
      final dateKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/manual-attendance/data'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'course_id': state.selectedCourseId,
              'semester': state.selectedSemester,
              'subject_id': state.selectedSubjectId,
              'date': dateKey,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List<dynamic> rawStudents = data['students'] ?? [];
        final Map<String, dynamic> rawAttendance =
            data['attendance_status'] ?? {};

        final List<Map<String, dynamic>> parsedStudents = rawStudents
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final Map<String, String> statusMap = {};

        rawAttendance.forEach((key, value) {
          statusMap[key.toString()] = value.toString();
        });

        state = state.copyWith(
          isLoading: false,
          students: parsedStudents,
          attendanceStatus: statusMap,
        );
      } else {
        throw Exception(
          jsonDecode(response.body)['message'] ?? "Failed to fetch data",
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Error fetching data: $e",
      );
    }
  }

  void toggleStudentStatus(String uid) {
    final currentStatus = state.attendanceStatus[uid];
    final newStatus = currentStatus == 'Present' ? 'Absent' : 'Present';
    final newMap = Map<String, String>.from(state.attendanceStatus);
    newMap[uid] = newStatus;
    state = state.copyWith(attendanceStatus: newMap);
  }

  void markAll(String status) {
    final newMap = Map<String, String>.from(state.attendanceStatus);
    for (var student in state.students) {
      newMap[student['id'].toString()] = status;
    }
    state = state.copyWith(attendanceStatus: newMap);
  }

  Future<void> saveAttendance(BuildContext context) async {
    if (state.attendanceStatus.isEmpty) return;

    state = state.copyWith(isLoading: true);

    try {
      final token = await _getToken();
      final dateKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);

      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/manual-attendance/save'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'subject_id': state.selectedSubjectId,
              'session_id': state.activeSessionId,
              'date': dateKey,
              'attendance_data': state.attendanceStatus,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        state = state.copyWith(isLoading: false);
        if (context.mounted) {
          Navigator.pop(context);
          Navigator.pop(context);
          CustomToast.show(context, "Attendance Records Updated Successfully");
        }
      } else {
        throw Exception(
          jsonDecode(response.body)['message'] ?? "Failed to save",
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "Failed to save: $e",
      );
    }
  }
}

class AdminManualAttendanceScreen extends ConsumerStatefulWidget {
  const AdminManualAttendanceScreen({super.key});

  @override
  ConsumerState<AdminManualAttendanceScreen> createState() =>
      _AdminManualAttendanceScreenState();
}

class _AdminManualAttendanceScreenState
    extends ConsumerState<AdminManualAttendanceScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(manualAttendanceProvider);
    final controller = ref.read(manualAttendanceProvider.notifier);

    ref.listen(manualAttendanceProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        CustomToast.show(context, next.errorMessage!, isError: true);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
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
          "Manual Attendance",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.black,
              size: 22,
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.black,
                        onPrimary: Colors.white,
                        onSurface: Colors.black,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) controller.setDate(picked);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.activeSessionId == null && !state.isLoading
          ? _buildNoSessionError()
          : Column(
              children: [
                _buildHeaderFilters(state, controller),
                Expanded(
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.black),
                        )
                      : state.students.isEmpty &&
                            state.selectedSubjectId != null
                      ? _buildEmptyState("No students found in this batch")
                      : state.selectedSubjectId == null
                      ? _buildEmptyState(
                          "Please select Course, Semester & Subject\nto fetch student list",
                        )
                      : _buildStudentList(state, controller),
                ),
              ],
            ),
      bottomNavigationBar: state.students.isNotEmpty
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
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AttendanceSummaryScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Review & Submit",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
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
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.people_alt_outlined,
              size: 48,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFilters(
    ManualAttendanceState state,
    ManualAttendanceController controller,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Filter Batch",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _FilterChip(
                  label: state.selectedCourseName ?? "Select Course",
                  icon: Icons.school_rounded,
                  isSelected: state.selectedCourseId != null,
                  onTap: () => _showCourseSheet(controller),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _FilterChip(
                  label: state.selectedSemester != null
                      ? "Sem ${state.selectedSemester}"
                      : "Sem",
                  icon: Icons.layers_rounded,
                  isSelected: state.selectedSemester != null,
                  onTap: () => _showSemesterSheet(controller),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FilterChip(
            label: state.selectedSubjectName ?? "Select Subject / Lab",
            icon: Icons.science_rounded,
            isSelected: state.selectedSubjectId != null,
            isActive:
                state.selectedCourseId != null &&
                state.selectedSemester != null,
            onTap: () {
              if (state.selectedCourseId != null &&
                  state.selectedSemester != null) {
                _showSubjectSheet(controller, state);
              } else {
                CustomToast.show(
                  context,
                  "Please select Course and Semester first",
                  isError: true,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showCourseSheet(ManualAttendanceController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SelectionSheet(
        title: "Select Course",
        apiUrl: "${ApiConfig.baseUrl}/courses",
        onSelect: (id, name) => controller.setCourse(id, name),
      ),
    );
  }

  void _showSemesterSheet(ManualAttendanceController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Select Semester",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: 8,
                itemBuilder: (context, index) {
                  final sem = index + 1;
                  return ListTile(
                    title: Text("Semester $sem", textAlign: TextAlign.center),
                    onTap: () {
                      controller.setSemester(sem);
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

  void _showSubjectSheet(
    ManualAttendanceController controller,
    ManualAttendanceState state,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SelectionSheet(
        title: "Select Subject",
        apiUrl:
            "${ApiConfig.baseUrl}/subjects?course_id=${state.selectedCourseId}&semester=${state.selectedSemester}&session_id=${state.activeSessionId}",
        onSelect: (id, name) => controller.setSubject(id, name),
      ),
    );
  }

  Widget _buildStudentList(
    ManualAttendanceState state,
    ManualAttendanceController controller,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${state.students.length} Students",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  _ActionTextBtn(
                    label: "All Present",
                    color: const Color(0xFF10B981),
                    onTap: () => controller.markAll('Present'),
                  ),
                  const SizedBox(width: 16),
                  _ActionTextBtn(
                    label: "All Absent",
                    color: const Color(0xFFEF4444),
                    onTap: () => controller.markAll('Absent'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: state.students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final student = state.students[index];
              final uid = student['id'].toString();
              final status = state.attendanceStatus[uid];
              final isPresent = status == 'Present';

              return _StudentAttendanceCard(
                name: student['name'] ?? "Unknown",
                rollNo: student['roll_number']?.toString() ?? "---",
                imageUrl: student['profile_pic'],
                isPresent: isPresent,
                onToggle: () => controller.toggleStudentStatus(uid),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoSessionError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Active Session",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Please create an academic session first",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class AttendanceSummaryScreen extends ConsumerWidget {
  const AttendanceSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(manualAttendanceProvider);
    final controller = ref.read(manualAttendanceProvider.notifier);

    final presentCount = state.attendanceStatus.values
        .where((e) => e == 'Present')
        .length;
    final absentCount = state.attendanceStatus.values
        .where((e) => e == 'Absent')
        .length;
    final notMarked = state.students.length - (presentCount + absentCount);

    return Scaffold(
      backgroundColor: Colors.white,
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
          "Summary",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('EEEE, dd MMM yyyy').format(state.selectedDate),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.selectedSubjectName ?? "Unknown Subject",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${state.selectedCourseName} • Sem ${state.selectedSemester}",
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _SummaryStatCard(
                    label: "Present",
                    count: presentCount,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SummaryStatCard(
                    label: "Absent",
                    count: absentCount,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (notMarked > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$notMarked students will be marked as 'Not Marked'",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
            if (state.isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.black),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => controller.saveAttendance(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF1A1A1A).withOpacity(0.4),
                  ),
                  child: const Text(
                    "Confirm & Save Records",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryStatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.isActive = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? (isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF3F4F6))
              : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.grey.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? (isSelected ? Colors.white : Colors.grey[600])
                  : Colors.grey[300],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? (isSelected ? Colors.white : const Color(0xFF1A1A1A))
                      : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isActive
                  ? (isSelected ? Colors.white70 : Colors.grey[400])
                  : Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  final String name;
  final String rollNo;
  final String? imageUrl;
  final bool isPresent;
  final VoidCallback onToggle;

  const _StudentAttendanceCard({
    required this.name,
    required this.rollNo,
    required this.imageUrl,
    required this.isPresent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              image: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (imageUrl == null || imageUrl!.isEmpty)
                ? Icon(Icons.person, color: Colors.grey[400])
                : null,
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
                Text(
                  rollNo,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 110,
              height: 44,
              decoration: BoxDecoration(
                color: isPresent
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isPresent
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : const Color(0xFFEF4444).withOpacity(0.2),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "A",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isPresent
                                ? const Color(0xFFEF4444).withOpacity(0.4)
                                : Colors.transparent,
                          ),
                        ),
                        Text(
                          "P",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: !isPresent
                                ? const Color(0xFF10B981).withOpacity(0.4)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.elasticOut,
                    alignment: isPresent
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 60,
                      height: 38,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (isPresent
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444))
                                    .withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isPresent ? "PRESENT" : "ABSENT",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
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
        ],
      ),
    );
  }
}

class _ActionTextBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTextBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SelectionSheet extends StatefulWidget {
  final String title;
  final String apiUrl;
  final Function(String, String) onSelect;

  const _SelectionSheet({
    required this.title,
    required this.apiUrl,
    required this.onSelect,
  });

  @override
  State<_SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<_SelectionSheet> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final response = await http.get(
        Uri.parse(widget.apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _items = data['data'] ?? data['subjects'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load data";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Network error";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      "No items found",
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final id = item['id'].toString();
                      final name =
                          item['name'] ?? item['subject_name'] ?? 'Unknown';
                      final code =
                          item.containsKey('code') ||
                              item.containsKey('subject_code')
                          ? "${item['code'] ?? item['subject_code']} - "
                          : "";

                      return GestureDetector(
                        onTap: () {
                          widget.onSelect(id, name);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.03),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "$code$name",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
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
    );
  }
}
