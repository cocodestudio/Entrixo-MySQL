import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/api_config.dart';
import '../../utils/custom_toast.dart';
import '../../widgets/geometric_loader.dart';
import '../widgets/export_dialog.dart';

class DailyHeadcountScreen extends StatefulWidget {
  const DailyHeadcountScreen({super.key});

  @override
  State<DailyHeadcountScreen> createState() => _DailyHeadcountScreenState();
}

class _DailyHeadcountScreenState extends State<DailyHeadcountScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isFetchingCount = false;

  String? _selectedCourseId;
  String? _selectedCourseName;
  int? _courseDuration;
  int? _selectedSemester;
  int? _currentTotalStudents;

  final TextEditingController _preController = TextEditingController();
  final TextEditingController _postController = TextEditingController();

  List<BatchHeadcountModel> _todayEntries = [];

  int _grandTotal = 0;
  int _grandPre = 0;
  int _grandPost = 0;

  @override
  void initState() {
    super.initState();
    _fetchDailyData();
  }

  @override
  void dispose() {
    _preController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchDailyData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      if (token == null) throw Exception("Unauthorized");

      final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/admin/headcount/date/$dateKey'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body)['data'];
        if (resData != null) {
          final List<dynamic> savedBatches = resData['batches'] ?? [];
          _todayEntries = savedBatches
              .map((e) => BatchHeadcountModel.fromMap(e))
              .toList();
        } else {
          _todayEntries = [];
        }
        _recalculateTotals();
      } else {
        _todayEntries = [];
        _recalculateTotals();
      }
    } catch (e) {
      if (mounted)
        CustomToast.show(context, "Error loading data", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudentCount() async {
    if (_selectedCourseId == null || _selectedSemester == null) return;

    setState(() => _isFetchingCount = true);
    try {
      final existingIndex = _todayEntries.indexWhere(
        (e) =>
            e.courseName == _selectedCourseName &&
            e.semester == "Sem $_selectedSemester",
      );

      if (existingIndex != -1) {
        final existing = _todayEntries[existingIndex];
        _currentTotalStudents = existing.totalStudents;
        _preController.text = existing.preLunch.toString();
        _postController.text = existing.postLunch.toString();
        setState(() => _isFetchingCount = false);
        return;
      }

      final token = await _getToken();
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/admin/headcount/student-count?course_id=$_selectedCourseId&semester=$_selectedSemester',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final count = jsonDecode(response.body)['count'] ?? 0;
        setState(() {
          _currentTotalStudents = count;
          _preController.clear();
          _postController.clear();
        });
      } else {
        throw Exception("Failed to load count");
      }
    } catch (e) {
      if (mounted)
        CustomToast.show(context, "Failed to fetch count", isError: true);
    } finally {
      setState(() => _isFetchingCount = false);
    }
  }

  void _addOrUpdateEntry() {
    if (_currentTotalStudents == null) return;
    FocusScope.of(context).unfocus();

    int pre = int.tryParse(_preController.text) ?? 0;
    int post = int.tryParse(_postController.text) ?? 0;

    if (pre > _currentTotalStudents! || post > _currentTotalStudents!) {
      CustomToast.show(
        context,
        "Count cannot exceed Total Students!",
        isError: true,
      );
      return;
    }

    final newEntry = BatchHeadcountModel(
      courseId:
          _selectedCourseId, // Sending courseId to backend for strict relations
      courseName: _selectedCourseName!,
      semester: "Sem $_selectedSemester",
      totalStudents: _currentTotalStudents!,
      preLunch: pre,
      postLunch: post,
    );

    setState(() {
      final index = _todayEntries.indexWhere(
        (e) =>
            e.courseName == newEntry.courseName &&
            e.semester == newEntry.semester,
      );

      if (index != -1) {
        _todayEntries[index] = newEntry;
      } else {
        _todayEntries.add(newEntry);
      }

      _selectedCourseId = null;
      _selectedCourseName = null;
      _selectedSemester = null;
      _currentTotalStudents = null;
      _preController.clear();
      _postController.clear();

      _recalculateTotals();
    });

    _saveToDatabase();
  }

  void _recalculateTotals() {
    int t = 0, p = 0, po = 0;
    for (var e in _todayEntries) {
      t += e.totalStudents;
      p += e.preLunch;
      po += e.postLunch;
    }
    setState(() {
      _grandTotal = t;
      _grandPre = p;
      _grandPost = po;
    });
  }

  Future<void> _saveToDatabase() async {
    try {
      final token = await _getToken();
      final String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final Map<String, dynamic> payload = {
        'date': dateKey,
        'grandTotal': _grandTotal,
        'grandPreLunch': _grandPre,
        'grandPostLunch': _grandPost,
        'batches': _todayEntries.map((e) => e.toMap()).toList(),
      };

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/admin/headcount/save'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        if (mounted)
          CustomToast.show(context, "Entry Saved Successfully", isError: false);
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      if (mounted) CustomToast.show(context, "Save Failed", isError: true);
    }
  }

  Future<List<dynamic>> _fetchCoursesList() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/admin/headcount/courses'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    }
    throw Exception('Failed to load courses');
  }

  void _showCourseSheet() {
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
            FutureBuilder<List<dynamic>>(
              future: _fetchCoursesList(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No courses available"));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 24),
                  itemBuilder: (context, index) {
                    final data = snapshot.data![index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        data['name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCourseId = data['id'].toString();
                          _selectedCourseName = data['name'];
                          _courseDuration = data['durationYears'];
                          _selectedSemester = null;
                          _currentTotalStudents = null;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSemesterSheet() {
    if (_selectedCourseId == null) {
      CustomToast.show(context, "Please select a course first", isError: true);
      return;
    }
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
                "Select Semester",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: (_courseDuration ?? 0) * 2,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  int sem = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedSemester = sem);
                      Navigator.pop(context);
                      _fetchStudentCount();
                    },
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
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

  Future<void> _saveFinalSheet() async {
    if (_todayEntries.isEmpty) {
      CustomToast.show(context, "No entries found to export!", isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ExportDialog(
        onPdfTap: () async {
          Navigator.pop(context);
          CustomToast.show(context, "Generating PDF...", isError: false);
          await ExportService.generatePdf(
            context,
            _selectedDate,
            _todayEntries,
            _grandTotal,
            _grandPre,
            _grandPost,
          );
        },
        onExcelTap: () async {
          Navigator.pop(context);
          CustomToast.show(context, "Generating Excel...", isError: false);
          await ExportService.generateExcel(
            context,
            _selectedDate,
            _todayEntries,
            _grandTotal,
            _grandPre,
            _grandPost,
          );
        },
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
          "Daily Headcount",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: GeometricLoader(size: 50, isDarkMode: false))
          : Column(
              children: [
                _buildDateSelector(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSelectionSection(),
                        const SizedBox(height: 24),
                        if (_isFetchingCount)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: GeometricLoader(
                                size: 30,
                                isDarkMode: false,
                              ),
                            ),
                          )
                        else if (_currentTotalStudents != null)
                          _buildInputSection(),
                        const SizedBox(height: 32),
                        if (_todayEntries.isNotEmpty) ...[
                          Text(
                            "TODAY'S ENTRIES",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[500],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _todayEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _BatchDisplayCard(model: _todayEntries[index]),
                          ),
                        ],
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GestureDetector(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2024),
            lastDate: DateTime(2030),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Colors.black,
                  onPrimary: Colors.white,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            ),
          );
          if (picked != null && picked != _selectedDate) {
            setState(() {
              _selectedDate = picked;
              _selectedCourseId = null;
              _currentTotalStudents = null;
            });
            _fetchDailyData();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    "Date",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy, EEEE').format(_selectedDate),
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
    );
  }

  Widget _buildSelectionSection() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _showCourseSheet,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedCourseId != null
                      ? Colors.black
                      : Colors.grey[300]!,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCourseName ?? "Select Course",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedCourseName != null
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: _selectedCourseName != null
                        ? Colors.black
                        : Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _showSemesterSheet,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedCourseId == null
                    ? Colors.grey[100]
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedSemester != null
                      ? Colors.black
                      : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedSemester != null
                          ? "Sem $_selectedSemester"
                          : "Sem",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _selectedSemester != null
                            ? Colors.black
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: _selectedSemester != null
                        ? Colors.black
                        : Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Headcount Entry",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Total: $_currentTotalStudents",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  "PRE-LUNCH",
                  _preController,
                  const Color(0xFF00D26A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField(
                  "POST-LUNCH",
                  _postController,
                  const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _addOrUpdateEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Add / Update Entry",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    Color accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.grey[400],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: Colors.black,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: "0",
            hintStyle: const TextStyle(color: Colors.black12),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _footerStat("TOTAL", "$_grandTotal", Colors.black),
              Container(height: 30, width: 1, color: Colors.grey[200]),
              _footerStat("PRE-LUNCH", "$_grandPre", const Color(0xFF00D26A)),
              Container(height: 30, width: 1, color: Colors.grey[200]),
              _footerStat("POST-LUNCH", "$_grandPost", const Color(0xFF4F46E5)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _todayEntries.isEmpty ? null : _saveFinalSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.save_rounded,
                    color: _todayEntries.isEmpty
                        ? Colors.white.withOpacity(0.5)
                        : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Save Final Sheet",
                    style: TextStyle(
                      color: _todayEntries.isEmpty
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _footerStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BatchDisplayCard extends StatelessWidget {
  final BatchHeadcountModel model;
  const _BatchDisplayCard({required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.courseName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  model.semester,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _miniBadge(model.preLunch.toString(), const Color(0xFF00D26A)),
              const SizedBox(width: 8),
              _miniBadge(model.postLunch.toString(), const Color(0xFF4F46E5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String val, Color color) {
    return Container(
      width: 40,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(
          val,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class BatchHeadcountModel {
  final String? courseId;
  final String courseName;
  final String semester;
  final int totalStudents;
  int preLunch;
  int postLunch;

  BatchHeadcountModel({
    this.courseId,
    required this.courseName,
    required this.semester,
    required this.totalStudents,
    this.preLunch = 0,
    this.postLunch = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'semester': semester,
      'totalStudents': totalStudents,
      'preLunch': preLunch,
      'postLunch': postLunch,
    };
  }

  factory BatchHeadcountModel.fromMap(Map<String, dynamic> map) {
    return BatchHeadcountModel(
      courseId: map['course_id']?.toString() ?? map['courseId']?.toString(),
      courseName: map['course_name'] ?? map['courseName'] ?? '',
      semester: map['semester'] ?? '',
      totalStudents: map['total_students'] ?? map['totalStudents'] ?? 0,
      preLunch: map['pre_lunch'] ?? map['preLunch'] ?? 0,
      postLunch: map['post_lunch'] ?? map['postLunch'] ?? 0,
    );
  }
}

// ----------------------------------------------------
// EXPORT SERVICE BELOW
// ----------------------------------------------------

class ExportService {
  static Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      if (await Permission.storage.request().isGranted) {
        return true;
      }
      return false;
    }
    return true;
  }

  static Future<String> _getDirectoryPath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/entrixo');
    } else {
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/entrixo');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.center,
    bool isBold = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      alignment: align,
      child: pw.Text(
        text,
        softWrap: false,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 9.5,
          fontWeight: (isHeader || isBold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static Future<void> generatePdf(
    BuildContext context,
    DateTime date,
    List<BatchHeadcountModel> batches,
    int grandTotal,
    int grandPre,
    int grandPost,
  ) async {
    if (!await _requestPermission()) return;

    final pdf = pw.Document();
    double prePercent = grandTotal == 0 ? 0 : (grandPre / grandTotal) * 100;
    double postPercent = grandTotal == 0 ? 0 : (grandPost / grandTotal) * 100;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                "SHOBHIT UNIVERSITY, GANGOH",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                "SCHOOL OF ENGINEERING & TECHNOLOGY",
                style: pw.TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(height: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "DAILY ATTENDANCE HEADCOUNT",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd-MMM-yyyy (EEEE)').format(date),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(25),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FixedColumnWidth(40),
                  4: const pw.FixedColumnWidth(55),
                  5: const pw.FixedColumnWidth(35),
                  6: const pw.FixedColumnWidth(55),
                  7: const pw.FixedColumnWidth(35),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue900,
                    ),
                    children: [
                      _buildCell("S.No", isHeader: true),
                      _buildCell("Program", isHeader: true),
                      _buildCell("Semester", isHeader: true),
                      _buildCell("Total", isHeader: true),
                      _buildCell("Pre-Lunch", isHeader: true),
                      _buildCell("%", isHeader: true),
                      _buildCell("Post-Lunch", isHeader: true),
                      _buildCell("%", isHeader: true),
                    ],
                  ),
                  ...List.generate(batches.length, (index) {
                    final b = batches[index];
                    double p1 = b.totalStudents == 0
                        ? 0
                        : (b.preLunch / b.totalStudents) * 100;
                    double p2 = b.totalStudents == 0
                        ? 0
                        : (b.postLunch / b.totalStudents) * 100;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 != 0
                            ? PdfColors.grey50
                            : PdfColors.white,
                      ),
                      children: [
                        _buildCell("${index + 1}"),
                        _buildCell(
                          b.courseName,
                          align: pw.Alignment.centerLeft,
                        ),
                        _buildCell(b.semester),
                        _buildCell("${b.totalStudents}"),
                        _buildCell("${b.preLunch}"),
                        _buildCell("${p1.toStringAsFixed(0)}%"),
                        _buildCell("${b.postLunch}"),
                        _buildCell("${p2.toStringAsFixed(0)}%"),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _buildCell(""),
                      _buildCell(
                        "GRAND TOTAL",
                        align: pw.Alignment.centerLeft,
                        isBold: true,
                      ),
                      _buildCell(""),
                      _buildCell("$grandTotal", isBold: true),
                      _buildCell("$grandPre", isBold: true),
                      _buildCell(
                        "${prePercent.toStringAsFixed(0)}%",
                        isBold: true,
                      ),
                      _buildCell("$grandPost", isBold: true),
                      _buildCell(
                        "${postPercent.toStringAsFixed(0)}%",
                        isBold: true,
                      ),
                    ],
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Report ID: ENT-${date.millisecondsSinceEpoch.toString().substring(7)}",
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      "Generated via Entrixo Admin Suite",
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final path = await _getDirectoryPath();
      final fileName = "Headcount_${DateFormat('ddMMMyyyy').format(date)}.pdf";
      final file = File("$path/$fileName");
      await file.writeAsBytes(await pdf.save());
      if (context.mounted)
        CustomToast.show(
          context,
          "Premium PDF Saved in entrixo folder",
          isError: false,
        );
    } catch (e) {
      if (context.mounted)
        CustomToast.show(context, "Export Failed", isError: true);
    }
  }

  static Future<void> generateExcel(
    BuildContext context,
    DateTime date,
    List<BatchHeadcountModel> batches,
    int gTotal,
    int gPre,
    int gPost,
  ) async {
    if (!await _requestPermission()) return;

    var xl = excel.Excel.createExcel();
    excel.Sheet sheet = xl['Sheet1'];

    excel.CellStyle headerStyle = excel.CellStyle(
      bold: true,
      fontColorHex: excel.ExcelColor.white,
      backgroundColorHex: excel.ExcelColor.blue,
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    excel.CellStyle dataStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    sheet.merge(
      excel.CellIndex.indexByString("A1"),
      excel.CellIndex.indexByString("H1"),
    );
    var titleCell = sheet.cell(excel.CellIndex.indexByString("A1"));
    titleCell.value = excel.TextCellValue(
      "SHOBHIT UNIVERSITY, GANGOH - Attendance Report",
    );
    titleCell.cellStyle = excel.CellStyle(
      bold: true,
      horizontalAlign: excel.HorizontalAlign.Center,
      fontSize: 14,
    );

    sheet.merge(
      excel.CellIndex.indexByString("A2"),
      excel.CellIndex.indexByString("H2"),
    );
    var dateCell = sheet.cell(excel.CellIndex.indexByString("A2"));
    dateCell.value = excel.TextCellValue(
      "Date: ${DateFormat('dd-MM-yyyy').format(date)}",
    );
    dateCell.cellStyle = excel.CellStyle(
      horizontalAlign: excel.HorizontalAlign.Center,
      italic: true,
    );

    List<String> headers = [
      'S.No.',
      'Program',
      'Semester',
      'Total',
      'Pre-Lunch',
      'Pre %',
      'Post-Lunch',
      'Post %',
    ];
    for (int i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3),
      );
      cell.value = excel.TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    for (int i = 0; i < batches.length; i++) {
      final b = batches[i];
      double p1 = b.totalStudents == 0
          ? 0
          : (b.preLunch / b.totalStudents) * 100;
      double p2 = b.totalStudents == 0
          ? 0
          : (b.postLunch / b.totalStudents) * 100;

      List<dynamic> rowData = [
        i + 1,
        b.courseName,
        b.semester,
        b.totalStudents,
        b.preLunch,
        "${p1.toStringAsFixed(1)}%",
        b.postLunch,
        "${p2.toStringAsFixed(1)}%",
      ];

      for (int col = 0; col < rowData.length; col++) {
        var cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 4),
        );
        cell.value = rowData[col] is int
            ? excel.IntCellValue(rowData[col])
            : excel.TextCellValue(rowData[col].toString());
        cell.cellStyle = dataStyle;
      }
    }

    int footerRow = batches.length + 4;
    double avgP1 = gTotal == 0 ? 0 : (gPre / gTotal) * 100;
    double avgP2 = gTotal == 0 ? 0 : (gPost / gTotal) * 100;

    List<dynamic> footerData = [
      '',
      'TOTAL SUMMARY',
      '',
      gTotal,
      gPre,
      "${avgP1.toStringAsFixed(1)}%",
      gPost,
      "${avgP2.toStringAsFixed(1)}%",
    ];

    excel.CellStyle footerStyle = excel.CellStyle(
      bold: true,
      fontColorHex: excel.ExcelColor.white,
      backgroundColorHex: excel.ExcelColor.green,
      horizontalAlign: excel.HorizontalAlign.Center,
      verticalAlign: excel.VerticalAlign.Center,
      leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
    );

    for (int col = 0; col < footerData.length; col++) {
      var cell = sheet.cell(
        excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: footerRow),
      );
      cell.value = footerData[col] is int
          ? excel.IntCellValue(footerData[col])
          : excel.TextCellValue(footerData[col].toString());
      cell.cellStyle = footerStyle;
    }

    sheet.setColumnWidth(0, 8.0);
    sheet.setColumnWidth(1, 20.0);
    sheet.setColumnWidth(2, 15.0);
    sheet.setColumnWidth(3, 10.0);
    sheet.setColumnWidth(4, 12.0);
    sheet.setColumnWidth(5, 12.0);
    sheet.setColumnWidth(6, 12.0);
    sheet.setColumnWidth(7, 12.0);

    try {
      final path = await _getDirectoryPath();
      final fileName = "Headcount_${DateFormat('ddMMMyyyy').format(date)}.xlsx";
      final file = File("$path/$fileName");
      await file.writeAsBytes(xl.encode()!);

      if (context.mounted) {
        CustomToast.show(
          context,
          "Excel Saved in Internal Storage/Entrixo",
          isError: false,
        );
      }
    } catch (e) {
      if (context.mounted)
        CustomToast.show(context, "Failed to save Excel", isError: true);
    }
  }
}
