import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_config.dart';
import '../widgets/geometric_loader.dart';

class AttendanceData {
  final List<Map<String, dynamic>> subjects;
  final double overallPercentage;
  final int totalClasses;
  final int totalPresent;
  final String activeSessionId;
  final String activeSessionName;

  AttendanceData({
    required this.subjects,
    required this.overallPercentage,
    required this.totalClasses,
    required this.totalPresent,
    required this.activeSessionId,
    required this.activeSessionName,
  });
}

final sessionListProvider =
    FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("User not logged in");

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/student/sessions'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'] ?? [];
        return data
            .map(
              (e) => {
                'id': e['id']?.toString() ?? '',
                'name': e['name']?.toString() ?? 'Unknown Session',
              },
            )
            .toList();
      } else {
        throw Exception("Failed to load sessions");
      }
    });

final selectedSessionProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

final attendanceProvider = FutureProvider.autoDispose
    .family<AttendanceData, String?>((ref, sessionId) async {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) throw Exception("User not logged in");

      String url = '${ApiConfig.baseUrl}/student/attendance';
      if (sessionId != null && sessionId.isNotEmpty) {
        url += '?session_id=$sessionId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] ?? {};

        if (sessionId == null && data['activeSessionId'] != null) {
          Future.microtask(() {
            if (ref.mounted) {
              ref.read(selectedSessionProvider.notifier).state =
                  data['activeSessionId'].toString();
            }
          });
        }

        List<Map<String, dynamic>> parsedSubjects = [];
        final subjectsList = data['subjects'] as List? ?? [];

        for (var sub in subjectsList) {
          List<Map<String, dynamic>> parsedSessions = [];
          final sessionsList = sub['sessions'] as List? ?? [];

          for (var ses in sessionsList) {
            DateTime parsedDate = DateTime.now();
            if (ses['date'] != null) {
              parsedDate =
                  DateTime.tryParse(ses['date'].toString()) ?? DateTime.now();
            }

            parsedSessions.add({...ses, 'date': parsedDate});
          }
          parsedSubjects.add({...sub, 'sessions': parsedSessions});
        }

        return AttendanceData(
          subjects: parsedSubjects,
          overallPercentage:
              (data['overallPercentage'] as num?)?.toDouble() ?? 0.0,
          totalClasses: (data['totalClasses'] as num?)?.toInt() ?? 0,
          totalPresent: (data['totalPresent'] as num?)?.toInt() ?? 0,
          activeSessionId: data['activeSessionId']?.toString() ?? '',
          activeSessionName:
              data['activeSessionName']?.toString() ?? 'No Active Session',
        );
      } else {
        throw Exception("Failed to load attendance data");
      }
    });

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final selectedSessionId = ref.watch(selectedSessionProvider);
    final attendanceAsync = ref.watch(attendanceProvider(selectedSessionId));
    final sessionListAsync = ref.watch(sessionListProvider);

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
          "Attendance",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: const Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: sessionListAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) return const SizedBox.shrink();

                final currentSession = sessions.firstWhere(
                  (s) => s['id'] == selectedSessionId,
                  orElse: () => sessions.first,
                );

                return GestureDetector(
                  onTap: () => _showPremiumSessionPicker(
                    context,
                    ref,
                    sessions,
                    selectedSessionId,
                    theme,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_motion_rounded,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Academic Session",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentSession['name'] ?? "Select Session",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.unfold_more_rounded,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: GeometricLoader(size: 20, isDarkMode: false),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: attendanceAsync.when(
              loading: () => Center(
                child: GeometricLoader(size: 50, isDarkMode: isDarkMode),
              ),
              error: (err, stack) =>
                  const Center(child: Text('Error loading data')),
              data: (data) {
                if (data.subjects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No subjects found for ${data.activeSessionName}",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: _OverallStatsCard(
                          percentage: data.overallPercentage > 1
                              ? data.overallPercentage / 100
                              : data.overallPercentage,
                          total: data.totalClasses,
                          present: data.totalPresent,
                          theme: theme,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final subject = data.subjects[index];
                          return _SubjectCard(theme: theme, data: subject);
                        }, childCount: data.subjects.length),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumSessionPicker(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, String>> sessions,
    String? selectedId,
    ThemeData theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Select Session",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  final isSelected = session['id'] == selectedId;

                  return InkWell(
                    onTap: () {
                      ref.read(selectedSessionProvider.notifier).state =
                          session['id'];
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primaryColor.withOpacity(0.05)
                            : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.grey,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            session['name'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? theme.primaryColor
                                  : Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: theme.primaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _OverallStatsCard extends StatelessWidget {
  final double percentage;
  final int total;
  final int present;
  final ThemeData theme;

  const _OverallStatsCard({
    required this.percentage,
    required this.total,
    required this.present,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A1A), Color(0xFF2C2C2C)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: _getColor(percentage),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text(
                    "${(percentage * 100).toInt()}%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overall Attendance",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Total Classes: $total",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                Text(
                  "Present: $present",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(double p) {
    if (p >= 0.75) return const Color(0xFF10B981);
    if (p >= 0.60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _SubjectCard extends StatelessWidget {
  final ThemeData theme;
  final Map<String, dynamic> data;

  const _SubjectCard({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    final int totalClasses = (data['total'] as num?)?.toInt() ?? 0;
    final int attendedClasses = (data['attended'] as num?)?.toInt() ?? 0;

    final double percentage = totalClasses == 0
        ? 0.0
        : attendedClasses / totalClasses;
    final int percentInt = (percentage * 100).toInt();
    final Color statusColor = _getColor(percentage);

    final String code = data['code']?.toString() ?? '---';
    final String name = data['name']?.toString() ?? 'Unknown Subject';
    final String faculty =
        data['faculty']?.toString() ?? 'Faculty Not Assigned';
    final String codeDisplay = code.contains('-') ? code.split('-').last : code;
    final String heroId = data['id']?.toString() ?? UniqueKey().toString();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectDetailScreen(data: data, theme: theme),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        codeDisplay,
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Hero(
                          tag: 'title_$heroId',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          faculty,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "$percentInt%",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MiniStat(label: 'Total', value: '$totalClasses'),
                  _MiniStat(
                    label: 'Present',
                    value: '$attendedClasses',
                    color: const Color(0xFF10B981),
                  ),
                  _MiniStat(
                    label: 'Absent',
                    value: '${totalClasses - attendedClasses}',
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor(double p) {
    if (p >= 0.75) return const Color(0xFF10B981);
    if (p >= 0.60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class SubjectDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final ThemeData theme;

  const SubjectDetailScreen({
    super.key,
    required this.data,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final List sessions = data['sessions'] as List? ?? [];

    final int totalClasses = (data['total'] as num?)?.toInt() ?? 0;
    final int attendedClasses = (data['attended'] as num?)?.toInt() ?? 0;

    final double percentage = totalClasses == 0
        ? 0.0
        : attendedClasses / totalClasses;
    final int percentInt = (percentage * 100).toInt();

    final String code = data['code']?.toString() ?? '---';
    final String name = data['name']?.toString() ?? 'Unknown Subject';
    final String faculty =
        data['faculty']?.toString() ?? 'Faculty Not Assigned';
    final String heroId = data['id']?.toString() ?? UniqueKey().toString();

    Color getStatusColor(String status) {
      if (status == 'Present') return const Color(0xFF10B981);
      if (status == 'Absent') return const Color(0xFFEF4444);
      if (status == 'Upcoming') return Colors.blue;
      return Colors.orange;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFF7F8FA),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primaryColor.withOpacity(0.05),
                      const Color(0xFFF7F8FA),
                    ],
                  ),
                ),
                child: Center(
                  child: Hero(
                    tag: 'progress_$heroId',
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: percentage,
                            strokeWidth: 8,
                            backgroundColor: Colors.white,
                            color: const Color(0xFF1A1A1A),
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$percentInt%',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1A1A1A),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const Text(
                                  "Attendance",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                    decoration: TextDecoration.none,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Hero(
                    tag: 'title_$heroId',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Text(
                      "$code • $faculty",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Session History",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          if (sessions.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text("No schedule found")),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final session = sessions[index];

                  final String status =
                      session['status']?.toString() ?? 'Unknown';
                  final String topic =
                      session['topic']?.toString() ?? 'Lab Session';
                  final String startTime =
                      session['startTime']?.toString() ?? '--:--';
                  final String endTime =
                      session['endTime']?.toString() ?? '--:--';

                  final DateTime dateObj = session['date'] is DateTime
                      ? session['date']
                      : DateTime.now();

                  final date = DateFormat('dd MMM').format(dateObj);
                  final day = DateFormat('EEE').format(dateObj);

                  final color = getStatusColor(status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                day,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: color.withOpacity(0.8),
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
                                topic,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$startTime - $endTime",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }, childCount: sessions.length),
              ),
            ),
        ],
      ),
    );
  }
}
