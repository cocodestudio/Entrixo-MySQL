import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin/admin_tools_screen.dart';
import '../screens/profile_controller.dart';
import '../utils/check_update.dart';
import '../utils/notification_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/custom_navbar.dart';
import '../widgets/dashboard_shimmer.dart';
import 'student_dashboard_components.dart';
import 'admin_components.dart';
import 'dashboard_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AppUpdateService.checkForUpdate();
      await NotificationService().requestPermission();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    final userAsync = ref.watch(userProfileProvider);

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) _onTabTapped(0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        extendBody: true,
        drawer: const CustomDrawer(),
        body: userAsync.when(
          loading: () => const Scaffold(
            backgroundColor: Color(0xFFF7F8FA),
            body: SafeArea(child: DashboardShimmer()),
          ),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (profileState) {
            final String role = profileState.role.toLowerCase().trim();
            final bool isAdmin = role == 'admin';

            bool isDataLoading = false;
            if (isAdmin) {
              isDataLoading = ref.watch(adminDashboardProvider).isLoading;
            } else {
              isDataLoading = ref.watch(dashboardControllerProvider).isLoading;
            }

            if (isDataLoading) {
              return Scaffold(
                backgroundColor: const Color(0xFFF7F8FA),
                body: SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 80 + topPadding),
                      const Expanded(child: DashboardShimmer()),
                    ],
                  ),
                ),
              );
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    physics: isAdmin
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    children: [
                      _buildDashboardContent(
                        theme,
                        size,
                        topPadding,
                        profileState.name,
                        profileState.profileUrl,
                        role,
                        ref,
                      ),
                      if (isAdmin) const AdminToolsScreen(),
                    ],
                  ),
                ),
                if (isAdmin)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomNavBar(
                      currentIndex: _currentIndex,
                      onTap: _onTabTapped,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    ThemeData theme,
    Size size,
    double topPadding,
    String userName,
    String? profileUrl,
    String role,
    WidgetRef ref,
  ) {
    final header = SliverPersistentHeader(
      pinned: true,
      delegate: DashboardHeader(
        userName: userName.isEmpty
            ? (role == 'admin' ? 'Admin' : 'Student')
            : userName,
        userImage: profileUrl,
        topPadding: topPadding,
      ),
    );

    if (role == "admin") {
      return CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          header,
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Column(
                  children: [
                    AdminStatsGrid(theme: theme),
                    const SizedBox(height: 2),
                    const ActiveLabsCarousel(),
                    const SizedBox(height: 10),
                    const AbsentAlertsList(),
                    const SizedBox(height: 140),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final studentState = ref.watch(dashboardControllerProvider);
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        header,
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              top: 24,
              bottom: role == 'admin' ? 140 : 40,
            ),
            child: Column(
              children: [
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
                NextSessionSection(
                  theme: theme,
                  sessions: studentState.upcomingSessions,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
