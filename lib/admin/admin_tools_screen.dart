import 'package:entrixo/admin/add_student_screen.dart';
import 'package:entrixo/admin/admin_daily_attendance_view.dart';
import 'package:entrixo/admin/admin_manual_attendance.dart';
import 'package:entrixo/admin/daily_headcount_screen.dart';
import 'package:entrixo/admin/lab_management_screen.dart';
import 'package:entrixo/admin/manage_faculty_screen.dart';
import 'package:entrixo/admin/qr_generator_screen.dart';
import 'package:entrixo/admin/resource_upload_screen.dart';
import 'package:entrixo/admin/session_management_screen.dart';
import 'package:entrixo/admin/student_list_screen.dart';
import 'package:flutter/material.dart';
import 'academic_setup_screen.dart';

class AdminToolsScreen extends StatelessWidget {
  const AdminToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, topPadding + 20, 24, 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Academic Tools",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Manage sessions, academics & reports",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HeroActionCard(
                  title: "Attendance Reports",
                  subtitle: "Download CSV & Analytics",
                  icon: Icons.bar_chart_rounded,
                  gradientColors: const [Color(0xFFFF9999), Color(0xFFFDD12E)],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DailyHeadcountScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildListDelegate([
                _GridActionCard(
                  title: "Academic\nSetup",
                  subtitle: "Manage Labs",
                  icon: Icons.hub_outlined,
                  gradientColors: const [Color(0xFF0288D1), Color(0xFF29B6F6)],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AcademicSetupScreen(),
                      ),
                    );
                  },
                ),
                _GridActionCard(
                  title: "Add\nStudent",
                  subtitle: "Manual Entry",
                  icon: Icons.person_add_alt_1_rounded,
                  gradientColors: const [Color(0xFF576574), Color(0xFF8395A7)],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddStudentScreen(),
                      ),
                    );
                  },
                ),
              ]),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverToBoxAdapter(
              child: _WideActionCard(
                title: "Lab Attendance",
                subtitle: "View Daily lab Attendance Reports",
                icon: Icons.bar_chart_rounded,
                gradientColors: [
                  theme.primaryColor,
                  theme.primaryColor.withBlue(200),
                ],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDailyAttendanceView(),
                    ),
                  );
                },
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                _GridActionCard(
                  title: "Academic\nSessions",
                  subtitle: "Create & Manage",
                  icon: Icons.history_edu_rounded,
                  gradientColors: const [Color(0xFF341f97), Color(0xFF5f27cd)],
                  isSmall: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SessionManagementScreen(),
                      ),
                    );
                  },
                ),

                _GridActionCard(
                  title: "Student\nDirectory",
                  subtitle: "View & Edit List",
                  icon: Icons.recent_actors_rounded,
                  gradientColors: const [Color(0xFF00b894), Color(0xFF55efc4)],
                  isSmall: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StudentListScreen(),
                      ),
                    );
                  },
                ),

                // 3. Faculty
                _GridActionCard(
                  title: "Faculty\nMembers",
                  subtitle: "Manage Staff",
                  icon: Icons.school_outlined,
                  gradientColors: const [Color(0xFFee5253), Color(0xFFff6b6b)],
                  isSmall: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddAdminScreen(),
                      ),
                    );
                  },
                ),

                // 4. Department Log
                _GridActionCard(
                  title: "Lab\nManage",
                  subtitle: "Computer Manages",
                  icon: Icons.assignment_outlined,
                  gradientColors: const [Color(0xFF2d3436), Color(0xFF636e72)],
                  isSmall: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AcademicEquipScreen(),
                      ),
                    );
                  },
                ),

                // 5. Broadcast (Notices)
                _GridActionCard(
                  title: "Student\nAttendance",
                  subtitle: "Manual attendance mark",
                  icon: Icons.bar_chart_sharp,
                  gradientColors: const [Color(0xFFe17055), Color(0xFFfab1a0)],
                  isSmall: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AdminManualAttendanceScreen(),
                      ),
                    );
                  },
                ),

                // 6. Timetable (New)
                _GridActionCard(
                  title: "Resources\nManage",
                  subtitle: "Manage Res. & Assign.",
                  icon: Icons.assignment_ind_rounded,
                  gradientColors: const [Color(0xFF6c5ce7), Color(0xFFa29bfe)],
                  isSmall: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ResourceUploadScreen(),
                      ),
                    );
                  },
                ),

                // // 7. Exams (New)
                // _GridActionCard(
                //   title: "Exams &\nResults",
                //   subtitle: "Grading",
                //   icon: Icons.grade_rounded,
                //   gradientColors: const [Color(0xFF0984e3), Color(0xFF74b9ff)],
                //   isSmall: true,
                //   onTap: () {},
                // ),
                //
                // // 8. Holidays (New)
                // _GridActionCard(
                //   title: "Holiday\nCalendar",
                //   subtitle: "Events",
                //   icon: Icons.celebration_rounded,
                //   gradientColors: const [Color(0xFFe84393), Color(0xFFfd79a8)],
                //   isSmall: true,
                //   onTap: () {},
                // ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _HeroActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -30,
                bottom: -40,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Icon(
                    icon,
                    size: 180,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    splashColor: Colors.white.withOpacity(0.2),
                    highlightColor: Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(icon, color: Colors.white, size: 32),
                          ),
                        ],
                      ),
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
}

class _GridActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool isSmall;

  const _GridActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -10,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(
                  icon,
                  size: isSmall ? 80 : 100,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withOpacity(0.1), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: isSmall ? 22 : 28,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmall ? 16 : 16,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _WideActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _WideActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: gradientColors,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -10,
              child: Transform.rotate(
                angle: 0.1,
                child: Icon(
                  icon,
                  size: 100,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  splashColor: Colors.white.withOpacity(0.2),
                  highlightColor: Colors.white.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 18,
                        ),
                      ],
                    ),
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
