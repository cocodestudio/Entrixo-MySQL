import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:entrixo/screens/student_assignment_screen.dart';
import 'package:entrixo/screens/student_resources_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/attendance_screen.dart';
import '../screens/student_scanner_screen.dart';
import 'dart:async';
import '../utils/api_config.dart';
import '../widgets/dashboard_shimmer.dart';

class DashboardState {
  final bool isLoading;
  final String userName;
  final double percentage;
  final int total;
  final int present;
  final int absent;
  final List<Map<String, dynamic>> upcomingSessions;

  DashboardState({
    required this.isLoading,
    required this.userName,
    this.percentage = 0.0,
    this.total = 0,
    this.present = 0,
    this.absent = 0,
    this.upcomingSessions = const [],
  });

  DashboardState copyWith({
    bool? isLoading,
    String? userName,
    double? percentage,
    int? total,
    int? present,
    int? absent,
    List<Map<String, dynamic>>? upcomingSessions,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      percentage: percentage ?? this.percentage,
      total: total ?? this.total,
      present: present ?? this.present,
      absent: absent ?? this.absent,
      upcomingSessions: upcomingSessions ?? this.upcomingSessions,
    );
  }
}

final dashboardControllerProvider =
    StateNotifierProvider<DashboardController, DashboardState>((ref) {
      return DashboardController();
    });

class DashboardController extends StateNotifier<DashboardState> {
  DashboardController()
    : super(DashboardState(isLoading: true, userName: 'Student')) {
    initData();
  }

  Future<void> initData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return;

      final userResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      String fetchedName = 'Student';
      if (userResponse.statusCode == 200) {
        fetchedName =
            jsonDecode(userResponse.body)['user']['name'] ?? 'Student';
      }

      final dashboardResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/student/dashboard'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (dashboardResponse.statusCode == 200) {
        final data = jsonDecode(dashboardResponse.body)['data'];
        final attendance = data['attendance'];

        if (mounted) {
          state = state.copyWith(
            isLoading: false,
            userName: fetchedName,
            total: attendance['total'],
            present: attendance['present'],
            absent: attendance['absent'],
            percentage: (attendance['percentage'] as num).toDouble(),
            upcomingSessions: List<Map<String, dynamic>>.from(
              data['upcoming_sessions'] ?? [],
            ),
          );
        }
      } else {
        if (mounted) {
          state = state.copyWith(isLoading: false, userName: fetchedName);
        }
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await initData();
  }
}

class StudentDashboardContent extends ConsumerWidget {
  final ThemeData theme;
  final Size size;

  const StudentDashboardContent({
    super.key,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(dashboardControllerProvider.notifier).refresh();
      },
      color: theme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LiveAttendanceCard(theme: theme),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryActionButton(theme: theme),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: QuickActionsSection(theme: theme),
            ),
            const SizedBox(height: 32),
            NextSessionSection(theme: theme, sessions: state.upcomingSessions),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class LiveAttendanceCard extends ConsumerWidget {
  final ThemeData theme;
  const LiveAttendanceCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);

    return StatsGlassCard(
      theme: theme,
      percentage: state.percentage,
      total: state.total,
      present: state.present,
      absent: state.absent,
    );
  }
}

class StatsGlassCard extends StatelessWidget {
  final ThemeData theme;
  final double percentage;
  final int total;
  final int present;
  final int absent;

  const StatsGlassCard({
    super.key,
    required this.theme,
    required this.percentage,
    required this.total,
    required this.present,
    required this.absent,
  });

  Color _getColor(double p) {
    if (p >= 0.75) return const Color(0xFF10B981);
    if (p >= 0.60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: percentage,
                      strokeWidth: 9,
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
                          fontSize: 18,
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
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      percentage >= 0.75
                          ? "Excellent! Keep it up."
                          : "Needs Improvement",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _smallPill("Total: $total", Colors.white24),
                        const SizedBox(width: 8),
                        _smallPill(
                          "Present: $present",
                          Colors.green.withOpacity(0.2),
                          textColor: Colors.greenAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomStat("Attended", "$present", Colors.greenAccent),
              _bottomStat("Absent", "$absent", Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallPill(
    String label,
    Color bg, {
    Color textColor = Colors.white70,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bottomStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class NextSessionSection extends StatelessWidget {
  final ThemeData theme;
  final List<Map<String, dynamic>> sessions;

  const NextSessionSection({
    super.key,
    required this.theme,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: _buildEmptyState(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Sessions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${sessions.length} Pending",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final bool isToday = session['isToday'] ?? false;

              return Container(
                width: 280,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(3, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF10B981)
                                : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isToday ? "TODAY" : session['displayDate'],
                            style: TextStyle(
                              color: isToday ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['subject'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session['code'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: Colors.white.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              session['faculty_name'] ?? 'N/A',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.access_time_filled_rounded,
                          session['time'],
                        ),
                        const SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.location_on_rounded,
                          session['room'],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 40,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            "No Upcoming Classes",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "You're all caught up for the next 3 days!",
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class PrimaryActionButton extends ConsumerWidget {
  final ThemeData theme;
  const PrimaryActionButton({super.key, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StudentScannerScreen()),
        );
        ref.read(dashboardControllerProvider.notifier).refresh();
      },
      child: Container(
        width: double.infinity,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.primaryColor, const Color(0xFF4F46E5)],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.4),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 100,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Scan QR Attendance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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
}

class QuickActionsSection extends StatelessWidget {
  final ThemeData theme;
  const QuickActionsSection({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickActionItem(
              icon: Icons.calendar_month_rounded,
              label: 'Attendance',
              color: const Color(0xFF6366F1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AttendanceScreen(),
                  ),
                );
              },
            ),
            _QuickActionItem(
              icon: Icons.assignment_rounded,
              label: 'Assignments',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentAssignmentScreen(),
                  ),
                );
              },
            ),
            _QuickActionItem(
              icon: Icons.menu_book_rounded,
              label: 'Resources',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentResourcesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 48 - 32) / 3;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9CA3AF).withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: onTap,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
